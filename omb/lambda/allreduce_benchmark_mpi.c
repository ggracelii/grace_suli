#include <mpi.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <hip/hip_runtime.h>  

// Enumeration for data types
typedef enum { TYPE_INT8, TYPE_INT, TYPE_FLOAT, TYPE_DOUBLE } DataType;

// Validation function to check if the received buffer matches expected values
int validate(void *recvbuf, int count, int size, int rank, DataType datatype) {
    double expected = (size - 1) * size / 2.0; // Calculate expected sum of ranks
    int errors = 0;

    // Iterate through the received buffer and validate each element
    for (int i = 0; i < count; i++) {
        double actual;
        switch (datatype) {
            case TYPE_INT8:   actual = ((int8_t *)recvbuf)[i]; break;
            case TYPE_DOUBLE: actual = ((double *)recvbuf)[i]; break;
            case TYPE_FLOAT:  actual = ((float *)recvbuf)[i]; break;
            case TYPE_INT:    actual = ((int *)recvbuf)[i]; break;
        }
        if (actual != expected) {
            printf("Rank %d: Expected output for message[%d] is %.2f. Actual output is %.2f\n",
                   rank, i, expected, actual);
            errors++;
        }
    }

    return errors;
}

int main(int argc, char *argv[]) {
    int rank, size, bytes, count;
    void *sendbuf, *recvbuf;
    double start, end;
    DataType datatype = TYPE_INT8;
    int type_size = sizeof(int8_t);
    MPI_Datatype mpi_type = MPI_INT8_T;
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

    int local_rank = -1;
    char *env_str = getenv("MPI_LOCALRANKID");
    if (env_str) {
        local_rank = atoi(env_str);
    } else {
        fprintf(stderr, "Rank %d: Could not get MPI_LOCALRANKID, defaulting to rank %% num_gpus\n", rank);
        int num_gpus;
        hipGetDeviceCount(&num_gpus);
        local_rank = rank % num_gpus;
    }

    // Assign unique GPU to this rank
    hipError_t err = hipSetDevice(local_rank);
    if (err != hipSuccess) {
        fprintf(stderr, "Rank %d: hipSetDevice(%d) failed: %s\n", rank, local_rank, hipGetErrorString(err));
        MPI_Abort(MPI_COMM_WORLD, 1);
    } else {
        printf("Rank %d assigned to GPU %d\n", rank, local_rank);
    }

    // Parse command-line args
    for (int i = 2; i < argc; i++) {
        if (strcmp(argv[i], "--corrupt") == 0) {
            corrupt = 1;
        } else if (strcmp(argv[i], "--int") == 0) {
            datatype = TYPE_INT;
            type_size = sizeof(int);
            mpi_type = MPI_INT; 
        } else if (strcmp(argv[i], "--float") == 0) {
            datatype = TYPE_FLOAT;
            type_size = sizeof(float);
            mpi_type = MPI_FLOAT; 
        } else if (strcmp(argv[i], "--double") == 0) {
            datatype = TYPE_DOUBLE;
            type_size = sizeof(double);
            mpi_type = MPI_DOUBLE; 
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

    // Allocate memory
    hipMalloc(&sendbuf, count * type_size);
    hipMalloc(&recvbuf, count * type_size);

    // Initialize send buffer with rank values
    for (int i = 0; i < count; i++) {
        switch (datatype) {
            case TYPE_INT8:
                ((int8_t *)sendbuf)[i] = (int8_t)rank; 
                break;
            case TYPE_DOUBLE:
                ((double *)sendbuf)[i] = (double)rank; 
                break;
            case TYPE_FLOAT:
                ((float *)sendbuf)[i] = (float)rank; 
                break;
            case TYPE_INT:
                ((int *)sendbuf)[i] = rank; 
                break;
        }
    }

    // Corrupt a random subset of ranks (at least one)
    int *corrupt_ranks = malloc(size * sizeof(int));
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

    // Time Allreduce
    MPI_Barrier(MPI_COMM_WORLD);
    start = MPI_Wtime();
    MPI_Allreduce(sendbuf, recvbuf, count, mpi_type, MPI_SUM, MPI_COMM_WORLD);
    end = MPI_Wtime();

    // Check results
    int local_errors = validate(recvbuf, count, size, rank, datatype);
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
    double local_time = end - start;
    double min_time, max_time, sum_time;

    MPI_Reduce(&local_time, &min_time, 1, MPI_DOUBLE, MPI_MIN, 0, MPI_COMM_WORLD);
    MPI_Reduce(&local_time, &max_time, 1, MPI_DOUBLE, MPI_MAX, 0, MPI_COMM_WORLD);
    MPI_Reduce(&local_time, &sum_time, 1, MPI_DOUBLE, MPI_SUM, 0, MPI_COMM_WORLD);

    if (rank == 0) {
        double avg_time = sum_time / size;
        printf("\nMPI Allreduce Timing Summary (type = %s, %d bytes/rank):\n",
            datatype == TYPE_DOUBLE ? "DOUBLE" :
            datatype == TYPE_FLOAT  ? "FLOAT"  :
            datatype == TYPE_INT    ? "INT"    : "INT8",
            bytes);
        printf("   Min Time: %.6f ms\n", min_time * 1000.0);
        printf("   Max Time: %.6f ms\n", max_time * 1000.0);
        printf("   Avg Time: %.6f ms\n", avg_time * 1000.0);
    }

    // Cleanup
    hipFree(sendbuf);
    hipFree(recvbuf);
    MPI_Finalize();
    return 0;
}