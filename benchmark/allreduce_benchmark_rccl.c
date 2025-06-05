#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <hip/hip_runtime.h>
#include <rccl/rccl.h>
#include <unistd.h>
#include <mpi.h>

#define CHECK(cmd) do { \
  hipError_t e = cmd; \
  if (e != hipSuccess) { \
    fprintf(stderr, "HIP error %s:%d '%s'\n", __FILE__,__LINE__,hipGetErrorString(e)); \
    exit(EXIT_FAILURE); \
  } \
} while (0)

#define RCCL_CHECK(cmd) do { \
  ncclResult_t r = cmd; \
  if (r != ncclSuccess) { \
    fprintf(stderr, "RCCL error %s:%d '%s'\n", __FILE__,__LINE__,ncclGetErrorString(r)); \
    exit(EXIT_FAILURE); \
  } \
} while (0)

// Enumeration for data types
typedef enum { TYPE_INT8, TYPE_INT, TYPE_FLOAT, TYPE_DOUBLE } DataType;

// Validation function to check if the received buffer matches expected values
int validate(void* recvbuf, int count, int size, int rank, DataType datatype) {
    double expected = (size - 1) * size / 2.0;
    int errors = 0;

    for (int i = 0; i < count; i++) {
        double actual;
        switch (datatype) {
            case TYPE_INT8:   actual = ((int8_t*)recvbuf)[i]; break;
            case TYPE_INT:    actual = ((int*)recvbuf)[i]; break;
            case TYPE_FLOAT:  actual = ((float*)recvbuf)[i]; break;
            case TYPE_DOUBLE: actual = ((double*)recvbuf)[i]; break;
        }
        if (actual != expected) {
            fprintf(stderr, "Rank %d: host_buf[%d] = %f (expected %f)\n", rank, i, actual, expected);
            errors++;
        }
    }

    return errors;
}

int main(int argc, char *argv[]) {
    int rank, size, bytes, count;
    void *sendbuf, *recvbuf;
    hipEvent_t start, end;
    DataType datatype = TYPE_INT8;
    int type_size = sizeof(int8_t);
    ncclDataType_t nccl_type = ncclInt8;
    int corrupt = 0;

    // Check command-line args
    if (argc < 2 || argc > 4) {
        if (rank == 0) {
            fprintf(stderr, "Usage: %s <message_size_in_bytes> [--int|--float|--double] [--corrupt]\n", argv[0]);
            fprintf(stderr, "Note: int8 is the default data type if none is specified.\n");
        }
        return 1;
    }

    // Initialize MPI stuff
    MPI_Init(&argc, &argv);
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);
    CHECK(hipSetDevice(rank));

    // Parse command-line args
    for (int i = 2; i < argc; i++) {
        if (strcmp(argv[i], "--corrupt") == 0) {
            corrupt = 1;
        } else if (strcmp(argv[i], "--int") == 0) {
            datatype = TYPE_INT;
            type_size = sizeof(int);
            nccl_type = ncclInt32;
        } else if (strcmp(argv[i], "--float") == 0) {
            datatype = TYPE_FLOAT;
            type_size = sizeof(float);
            nccl_type = ncclFloat32;
        } else if (strcmp(argv[i], "--double") == 0) {
            datatype = TYPE_DOUBLE;
            type_size = sizeof(double);
            nccl_type = ncclFloat64;
        } else {
            if (rank == 0) {
                fprintf(stderr, "Unknown option: %s\nUsage: %s <message_size_in_bytes> [--int|--float|--double] [--corrupt]\n", argv[i], argv[0]);
                fprintf(stderr, "Note: int8 is the default data type if none is specified.\n");
            }
            MPI_Finalize();
            return 1;
        }
    }

    // Calculate number of elements based on message size
    bytes = atoi(argv[1]);
    count = bytes / type_size;
    if (count <= 0) {
        if (rank == 0) {
            fprintf(stderr, "Message size too small: must be at least %d bytes\n", type_size);
        }
        MPI_Finalize();
        return 1;
    }

    // Allocate GPU memory
    CHECK(hipMalloc(&sendbuf, count * type_size));
    CHECK(hipMalloc(&recvbuf, count * type_size));
    hipStream_t stream;
    CHECK(hipStreamCreate(&stream));

    // Allocate and initialize host buffer
    void* host_buf = malloc(count * type_size);
    for (int i = 0; i < count; i++) {
        switch (datatype) {
            case TYPE_INT8:
                ((int8_t *)host_buf)[i] = (int8_t)rank;
                break;
            case TYPE_INT:
                ((int *)host_buf)[i] = rank; 
                break;
            case TYPE_FLOAT:  
                ((float*)host_buf)[i] = (float)rank; 
                break;
            case TYPE_DOUBLE: 
                ((double*)host_buf)[i] = (double)rank; 
                break;
        }
    }

    CHECK(hipMemcpy(sendbuf, host_buf, count * type_size, hipMemcpyHostToDevice));

    // Unique ID exchange
    ncclUniqueId id;
    if (rank == 0) {
        ncclGetUniqueId(&id);
    }

    MPI_Bcast(&id, sizeof(ncclUniqueId), MPI_BYTE, 0, MPI_COMM_WORLD);

    // Corrupt a random subset of ranks (at least one)
    int *corrupt_ranks = (int *)malloc(size * sizeof(int));
    memset(corrupt_ranks, 0, size * sizeof(int));

    if (corrupt && rank == 0) {
        srand(time(NULL));
        int num_to_corrupt = 1 + rand() % size;
        int selected = 0;
        while (selected < num_to_corrupt) {
            int r = rand() % size;
            if (corrupt_ranks[r] == 0) {
                corrupt_ranks[r] = 1;
                selected++;
            }
        }
    }

    MPI_Bcast(corrupt_ranks, size, MPI_INT, 0, MPI_COMM_WORLD);

    if (corrupt && corrupt_ranks[rank] && count >= 1) {
        srand(time(NULL) + rank);
        int num = rand() % count;
        switch (datatype) {
            case TYPE_INT8:
                ((int8_t *)sendbuf)[num] = 99; 
                break;
            case TYPE_DOUBLE:
                ((double *)sendbuf)[num] = 999.0;
                break;
            case TYPE_FLOAT:
                ((float *)sendbuf)[num] = 999.0f; 
                break;
            case TYPE_INT:
                ((int *)sendbuf)[num] = 999; 
                break;
        }
        printf("Rank %d: Corruption injected at sendbuf[%d]\n", rank, num);
    }

    MPI_Barrier(MPI_COMM_WORLD);
    if (rank == 0 && corrupt) {
     
       printf("All corruption injections completed.\n\n");
    }

    free(corrupt_ranks);

    // Initialize RCCL communicator
    ncclComm_t comm;
    RCCL_CHECK(ncclCommInitRank(&comm, size, id, rank));

    // Time AllReduce
    CHECK(hipEventCreate(&start));
    CHECK(hipEventCreate(&end));
    CHECK(hipEventRecord(start, stream));

    RCCL_CHECK(ncclAllReduce(sendbuf, recvbuf, count, nccl_type, ncclSum, comm, stream));

    CHECK(hipEventRecord(end, stream));
    CHECK(hipEventSynchronize(end));

    float elapsed_ms = 0.0f;
    CHECK(hipEventElapsedTime(&elapsed_ms, start, end));
    CHECK(hipEventDestroy(start));
    CHECK(hipEventDestroy(end));

    CHECK(hipMemcpy(host_buf, recvbuf, count * type_size, hipMemcpyDeviceToHost));

    // Check results
    int local_errors = validate(host_buf, count, size, rank, datatype);
    int total_errors = 0;
    MPI_Reduce(&local_errors, &total_errors, 1, MPI_INT, MPI_SUM, 0, MPI_COMM_WORLD);
    MPI_Barrier(MPI_COMM_WORLD);

    if (rank == 0) {
        if (total_errors == 0)
            printf("\nValidation passed. All values are correct across all %d ranks.\n", size);
        else
            printf("\nValidation failed. Total errors across all ranks: %d\n", total_errors);
    }

    // Print timing summary
    double local_time = elapsed_ms;
    double min_time, max_time, sum_time;

    MPI_Reduce(&local_time, &min_time, 1, MPI_DOUBLE, MPI_MIN, 0, MPI_COMM_WORLD);
    MPI_Reduce(&local_time, &max_time, 1, MPI_DOUBLE, MPI_MAX, 0, MPI_COMM_WORLD);
    MPI_Reduce(&local_time, &sum_time, 1, MPI_DOUBLE, MPI_SUM, 0, MPI_COMM_WORLD);

    if (rank == 0) {
        double avg_time = sum_time / size;
        printf("\nRCCL Allreduce Timing Summary (type = %s, %d bytes/rank):\n",
            datatype == TYPE_DOUBLE ? "DOUBLE" :
            datatype == TYPE_FLOAT  ? "FLOAT"  :
            datatype == TYPE_INT    ? "INT"    : "INT8",
            bytes);
        printf("   Min Time: %.6f ms\n", min_time);
        printf("   Max Time: %.6f ms\n", max_time);
        printf("   Avg Time: %.6f ms\n", avg_time);
    }

    // Cleanup
    free(host_buf);
    CHECK(hipFree(sendbuf));
    CHECK(hipFree(recvbuf));
    CHECK(hipStreamDestroy(stream));
    ncclCommDestroy(comm);
    MPI_Finalize();

    return 0;
}