/*
 * Copyright (c) 2002-2024 the Network-Based Computing Laboratory
 * (NBCL), The Ohio State University.
 *
 * Contact: Dr. D. K. Panda (panda@cse.ohio-state.edu)
 *
 * For detailed copyright and licensing information, please refer to the
 * copyright file COPYRIGHT in the top level OMB directory.
 */

#define BENCHMARK "OSU MPI%s Allreduce Latency Test"
#include <osu_util_mpi.h>

void run_allreduce_loop(
    MPI_Comm comm,
    char *sendbuf, char *recvbuf,
    char *sendbuf_warmup, char *recvbuf_warmup,
    size_t start_size, size_t end_size,
    MPI_Datatype datatype, int mpi_type_size,
    enum accel_type accel,
    int rank, int numprocs,
    int papi_eventset,
    double *omb_lat_arr,
    omb_graph_data_t **omb_graph_data,
    omb_graph_options_t *omb_graph_options,
    struct omb_stat_t *omb_stat,
    struct omb_buffer_sizes_t *omb_buffer_sizes
) {
    int i, j, num_elements, errors = 0, local_errors = 0;
    double t_start, t_stop, timer, latency, avg_time, min_time, max_time;

    for (size_t size = start_size; size <= end_size; size *= 2) {
        num_elements = size / mpi_type_size;
        if (0 == num_elements) continue;

        if (size > LARGE_MESSAGE_SIZE) {
            options.skip = options.skip_large;
            options.iterations = options.iterations_large;
        }

        omb_graph_allocate_and_get_data_buffer(omb_graph_data, omb_graph_options, size, options.iterations);

        MPI_CHECK(MPI_Barrier(comm));
        timer = 0.0;

        if (options.omb_enable_mpi_in_place == 1)
            sendbuf = MPI_IN_PLACE;

        for (i = 0; i < options.iterations + options.skip; i++) {
            if (i == options.skip) omb_papi_start(&papi_eventset);

            if (options.validate) {
                set_buffer_validation(sendbuf, recvbuf, size, accel, i, datatype, *omb_buffer_sizes);
                for (j = 0; j < options.warmup_validation; j++) {
                    MPI_CHECK(MPI_Barrier(comm));
                    MPI_CHECK(MPI_Allreduce(sendbuf_warmup, recvbuf_warmup, num_elements, datatype, MPI_SUM, comm));
                }
                MPI_CHECK(MPI_Barrier(comm));
            }

            t_start = MPI_Wtime();
            MPI_CHECK(MPI_Allreduce(sendbuf, recvbuf, num_elements, datatype, MPI_SUM, comm));
            t_stop = MPI_Wtime();
            MPI_CHECK(MPI_Barrier(comm));

            if (options.validate) {
                local_errors += validate_data(recvbuf, size, numprocs, accel, i, datatype);
            }

            if (i >= options.skip) {
                timer += t_stop - t_start;
                if (options.omb_tail_lat) omb_lat_arr[i - options.skip] = (t_stop - t_start) * 1e6;
                if (options.graph && rank == 0) (*omb_graph_data)->data[i - options.skip] = (t_stop - t_start) * 1e6;
            }
        }

        omb_papi_stop_and_print(&papi_eventset, size);
        latency = (double)(timer * 1e6) / options.iterations;
        MPI_CHECK(MPI_Reduce(&latency, &min_time, 1, MPI_DOUBLE, MPI_MIN, 0, comm));
        MPI_CHECK(MPI_Reduce(&latency, &max_time, 1, MPI_DOUBLE, MPI_MAX, 0, comm));
        MPI_CHECK(MPI_Reduce(&latency, &avg_time, 1, MPI_DOUBLE, MPI_SUM, 0, comm));
        avg_time = avg_time / numprocs;

        *omb_stat = omb_get_stats(omb_lat_arr);

        if (options.validate) MPI_CHECK(MPI_Allreduce(&local_errors, &errors, 1, MPI_INT, MPI_SUM, comm));

        if (options.validate)
            print_stats_validate(rank, size, avg_time, min_time, max_time, errors, *omb_stat);
        else
            print_stats(rank, size, avg_time, min_time, max_time, *omb_stat);

        if (options.graph && rank == 0)
            (*omb_graph_data)->avg = avg_time;

        MPI_CHECK(MPI_Barrier(comm));
        if (errors != 0) break;
    }
}

int main(int argc, char *argv[])
{
    int i, j, numprocs, rank, size;
    double latency = 0.0, t_start = 0.0, t_stop = 0.0;
    double timer = 0.0;
    double avg_time = 0.0, max_time = 0.0, min_time = 0.0;
    char *sendbuf, *recvbuf;
    void *sendbuf_warmup = NULL, *recvbuf_warmup = NULL;
    int po_ret;
    int errors = 0, local_errors = 0;
    size_t bufsize;
    omb_graph_options_t omb_graph_options;
    omb_graph_data_t *omb_graph_data = NULL;
    int papi_eventset = OMB_PAPI_NULL;
    options.bench = COLLECTIVE;
    options.subtype = ALL_REDUCE;
    size_t num_elements = 0;
    MPI_Datatype omb_curr_datatype = MPI_SIGNED_CHAR;
    int mpi_type_itr = 0, mpi_type_size = 0, mpi_type_name_length = 0;
    char mpi_type_name_str[OMB_DATATYPE_STR_MAX_LEN];
    MPI_Datatype mpi_type_list[OMB_NUM_DATATYPES];
    MPI_Comm omb_comm = MPI_COMM_NULL;
    omb_mpi_init_data omb_init_h;
    struct omb_buffer_sizes_t omb_buffer_sizes;
    double *omb_lat_arr = NULL;
    struct omb_stat_t omb_stat;

    set_header(HEADER);
    set_benchmark_name("osu_allreduce");
    po_ret = process_options(argc, argv);
    omb_populate_mpi_type_list(mpi_type_list);

    if (PO_OKAY == po_ret && NONE != options.accel) {
        if (init_accel()) {
            fprintf(stderr, "Error initializing device\n");
            exit(EXIT_FAILURE);
        }
    }

    omb_init_h = omb_mpi_init(&argc, &argv);
    omb_comm = omb_init_h.omb_comm;
    if (MPI_COMM_NULL == omb_comm) {
        OMB_ERROR_EXIT("Cant create communicator");
    }
    MPI_CHECK(MPI_Comm_rank(omb_comm, &rank));
    MPI_CHECK(MPI_Comm_size(omb_comm, &numprocs));

    omb_graph_options_init(&omb_graph_options);
    switch (po_ret) {
        case PO_BAD_USAGE:
            print_bad_usage_message(rank);
            omb_mpi_finalize(omb_init_h);
            exit(EXIT_FAILURE);
        case PO_HELP_MESSAGE:
            print_help_message(rank);
            omb_mpi_finalize(omb_init_h);
            exit(EXIT_SUCCESS);
        case PO_VERSION_MESSAGE:
            print_version_message(rank);
            omb_mpi_finalize(omb_init_h);
            exit(EXIT_SUCCESS);
        case PO_OKAY:
            break;
    }

    if (numprocs < 2) {
        if (rank == 0) {
            fprintf(stderr, "This test requires at least two processes\n");
        }
        omb_mpi_finalize(omb_init_h);
        exit(EXIT_FAILURE);
    }

    if (options.omb_tail_lat) {
        omb_lat_arr = malloc(options.iterations * sizeof(double));
        OMB_CHECK_NULL_AND_EXIT(omb_lat_arr, "Unable to allocate memory");
    }

    print_preamble(rank);
    omb_papi_init(&papi_eventset);

    if (options.tuning) {
        for (mpi_type_itr = 0; mpi_type_itr < options.omb_dtype_itr; mpi_type_itr++) {
            MPI_CHECK(MPI_Type_size(mpi_type_list[mpi_type_itr], &mpi_type_size));
            omb_curr_datatype = mpi_type_list[mpi_type_itr];
            OMB_MPI_REDUCE_CHAR_CHECK(omb_curr_datatype);
            MPI_CHECK(MPI_Type_get_name(omb_curr_datatype, mpi_type_name_str, &mpi_type_name_length));
            OMB_MPI_RUN_AT_RANK_ZERO(fprintf(stdout, "# Datatype: %s.\n", mpi_type_name_str));
            fflush(stdout);
            print_only_header(rank);

            bufsize = options.threshold;
            allocate_memory_coll((void **)&sendbuf, bufsize, NONE);
            allocate_memory_coll((void **)&recvbuf, bufsize, NONE);
            set_buffer(sendbuf, NONE, 1, bufsize);
            set_buffer(recvbuf, NONE, 0, bufsize);
            sendbuf_warmup = sendbuf;
            recvbuf_warmup = recvbuf;
            printf("Allocating CPU memory for buffers of size %zu bytes\n", bufsize);
            run_allreduce_loop(
                omb_comm, sendbuf, recvbuf,
                sendbuf_warmup, recvbuf_warmup,
                options.min_message_size, options.threshold,
                omb_curr_datatype, mpi_type_size, NONE,
                rank, numprocs, papi_eventset, omb_lat_arr,
                &omb_graph_data, &omb_graph_options, &omb_stat,
                &omb_buffer_sizes
            );
            if (sendbuf_warmup) {
                free_buffer(sendbuf_warmup, NONE);
                sendbuf_warmup = NULL;
            }
            if (recvbuf_warmup) {
                free_buffer(recvbuf_warmup, NONE);
                recvbuf_warmup = NULL;
            }

            bufsize = options.max_message_size;
            allocate_memory_coll((void **)&sendbuf, bufsize, ROCM);
            allocate_memory_coll((void **)&recvbuf, bufsize, ROCM);
            set_buffer(sendbuf, ROCM, 1, bufsize);
            set_buffer(recvbuf, ROCM, 0, bufsize);
            sendbuf_warmup = sendbuf;
            recvbuf_warmup = recvbuf;
            printf("Allocating ROCm memory for buffers of size %zu bytes\n", bufsize);
            run_allreduce_loop(
                omb_comm, sendbuf, recvbuf,
                sendbuf_warmup, recvbuf_warmup,
                options.threshold * 2, options.max_message_size,
                omb_curr_datatype, mpi_type_size, ROCM,
                rank, numprocs, papi_eventset, omb_lat_arr,
                &omb_graph_data, &omb_graph_options, &omb_stat,
                &omb_buffer_sizes
            );
            if (sendbuf_warmup) {
                free_buffer(sendbuf_warmup, ROCM);
                sendbuf_warmup = NULL;
            }
            if (recvbuf_warmup) {
                free_buffer(recvbuf_warmup, ROCM);
                recvbuf_warmup = NULL;
            }
        } 
    } else {
        bufsize = (options.max_message_size);
        if (allocate_memory_coll((void **)&sendbuf, bufsize, options.accel)) {
            fprintf(stderr, "Could Not Allocate Memory [rank %d]\n", rank);
            MPI_CHECK(MPI_Abort(omb_comm, EXIT_FAILURE));
        }
        set_buffer(sendbuf, options.accel, 1, bufsize);
        omb_buffer_sizes.sendbuf_size = bufsize;
        sendbuf_warmup = sendbuf;

        bufsize = (options.max_message_size);
        if (allocate_memory_coll((void **)&recvbuf, bufsize, options.accel)) {
            fprintf(stderr, "Could Not Allocate Memory [rank %d]\n", rank);
            MPI_CHECK(MPI_Abort(omb_comm, EXIT_FAILURE));
        }
        omb_buffer_sizes.recvbuf_size = bufsize;
        set_buffer(recvbuf, options.accel, 0, bufsize);
        for (mpi_type_itr = 0; mpi_type_itr < options.omb_dtype_itr; mpi_type_itr++) {
            MPI_CHECK(MPI_Type_size(mpi_type_list[mpi_type_itr], &mpi_type_size));
            omb_curr_datatype = mpi_type_list[mpi_type_itr];
            OMB_MPI_REDUCE_CHAR_CHECK(omb_curr_datatype);
            MPI_CHECK(MPI_Type_get_name(omb_curr_datatype, mpi_type_name_str,
                                        &mpi_type_name_length));
            OMB_MPI_RUN_AT_RANK_ZERO(
                fprintf(stdout, "# Datatype: %s.\n", mpi_type_name_str));
            fflush(stdout);
            print_only_header(rank);
            run_allreduce_loop(
                omb_comm, sendbuf, recvbuf,
                sendbuf_warmup, recvbuf_warmup,
                options.min_message_size, options.max_message_size,
                omb_curr_datatype, mpi_type_size, options.accel,
                rank, numprocs, papi_eventset, omb_lat_arr,
                &omb_graph_data, &omb_graph_options, &omb_stat,
                &omb_buffer_sizes
            );
        }
        if (sendbuf) free_buffer(sendbuf, options.accel);
        if (recvbuf) free_buffer(recvbuf, options.accel);
    }
    

    if (0 == rank && options.graph) omb_graph_plot(&omb_graph_options, benchmark_name);
    omb_graph_combined_plot(&omb_graph_options, benchmark_name);
    omb_graph_free_data_buffers(&omb_graph_options);
    omb_papi_free(&papi_eventset);
    free(omb_lat_arr);
    omb_mpi_finalize(omb_init_h);

    if (NONE != options.accel) {
        if (cleanup_accel()) {
            fprintf(stderr, "Error cleaning up device\n");
            exit(EXIT_FAILURE);
        }
    }

    if (0 != errors && options.validate && 0 == rank) {
        fprintf(stdout, "DATA VALIDATION ERROR: %s exited with status %d on message size %d.\n", argv[0], EXIT_FAILURE, size);
        exit(EXIT_FAILURE);
    }

    return EXIT_SUCCESS;
}