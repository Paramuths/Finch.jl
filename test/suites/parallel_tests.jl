# FIXME: Add a test for failures of concurrent.
@testitem "parallel" setup = [CheckOutput] begin
    if Threads.nthreads() <= 1
        @test true skip = true
    else
        using LinearAlgebra

        let
            io = IOBuffer()
            A = Tensor(Dense(SparseList(Element(0.0))), [1 2; 3 4])
            x = Tensor(Dense(Element(0.0)), [1, 1])
            y = Tensor(Dense(Element(0.0)))

            check_output(
                "parallel/parallel_spmv.txt", @finch_code begin
                    y .= 0
                    for j in parallel(_)
                        for i in _
                            y[j] += x[i] * A[walk(i), j]
                        end
                    end
                end
            )

            @repl io @finch begin
                y .= 0
                for j in parallel(_)
                    for i in _
                        y[j] += x[i] * A[walk(i), j]
                    end
                end
            end
        end

        let
            io = IOBuffer()
            A = fsprand(UInt, 42, 42, 0.1)
            B = fsprand(UInt, 42, 42, 0.1)
            CR = Tensor(Dense(Dense(Element(UInt(0)))), undef, 42, 42)
            @finch begin
                CR .= 0
                for i in _
                    for j in _
                        for k in _
                            CR[i, j] += A[i, k] * B[k, j]
                        end
                    end
                end
            end

            AFormat = SparseList(Dense(Element(UInt(0))))
            At = Tensor(AFormat, A)
            BFormat = Dense(SparseList(Element(UInt(0))))
            Bt = Tensor(BFormat, B)
            Ct = Tensor(Dense(Dense(Element(UInt(0)))), undef, 42, 42)
            check_output(
                "parallel/parallel_spmms_no_atomics_1.txt",
                @finch_code begin
                    Ct .= 0
                    for i in parallel(_)
                        for j in _
                            for k in _
                                Ct[i, j] += A[i, k] * B[k, j]
                            end
                        end
                    end
                end
            )
            @finch begin
                Ct .= 0
                for i in parallel(_)
                    for j in _
                        for k in _
                            Ct[i, j] += A[i, k] * B[k, j]
                        end
                    end
                end
            end

            @test Ct == CR

            check_output(
                "parallel/parallel_spmms_no_atomics_2.txt",
                @finch_code begin
                    Ct .= 0
                    for i in _
                        for j in parallel(_)
                            for k in _
                                Ct[i, j] += A[i, k] * B[k, j]
                            end
                        end
                    end
                end
            )
            @finch begin
                Ct .= 0
                for i in _
                    for j in parallel(_)
                        for k in _
                            Ct[i, j] += A[i, k] * B[k, j]
                        end
                    end
                end
            end

            @test Ct == CR

            check_output(
                "parallel/parallel_spmms_no_atomics_3.txt",
                @finch_code begin
                    Ct .= 0
                    for j in parallel(_)
                        for i in _
                            for k in _
                                Ct[i, j] += A[i, k] * B[k, j]
                            end
                        end
                    end
                end
            )
            @finch begin
                Ct .= 0
                for j in parallel(_)
                    for i in _
                        for k in _
                            Ct[i, j] += A[i, k] * B[k, j]
                        end
                    end
                end
            end

            @test Ct == CR

            check_output(
                "parallel/parallel_spmms_no_atomics_4.txt",
                @finch_code begin
                    Ct .= 0
                    for j in _
                        for i in parallel(_)
                            for k in _
                                Ct[i, j] += A[i, k] * B[k, j]
                            end
                        end
                    end
                end
            )
            @finch begin
                Ct .= 0
                for j in _
                    for i in parallel(_)
                        for k in _
                            Ct[i, j] += A[i, k] * B[k, j]
                        end
                    end
                end
            end

            @test Ct == CR

            check_output(
                "parallel/parallel_spmms_no_atomics_5.txt",
                @finch_code begin
                    Ct .= 0
                    for j in parallel(_)
                        for i in parallel(_)
                            for k in _
                                Ct[i, j] += A[i, k] * B[k, j]
                            end
                        end
                    end
                end
            )
            @finch begin
                Ct .= 0
                for j in parallel(_)
                    for i in parallel(_)
                        for k in _
                            Ct[i, j] += A[i, k] * B[k, j]
                        end
                    end
                end
            end

            @test Ct == CR
        end

        #=
        formats = [Dense, SparseList]
        for fmatA1 in formats
            for fmatA2 in formats
                Af = fmatA2(fmatA1(Element(UInt(0))))
                At = Tensor(Af, A)
                for fmatB1 in formats
                    for fmatB2 in formats
                        Bf = fmatB2(fmatB1(Element(UInt(0))))
                        Bt = Tensor(Bf, B)

                        Ct = Tensor(Dense(Dense(Element(UInt(0)))), undef, 42, 42)
                        check_output("parallel/debug_spmm_atomics_$fmtA1_$fmtA2_1.txt", @finch_code begin
                            Ct .= 0
                            for i = parallel(_)
                                for j = _
                                    for k = _
                                        Ct[i, j] += A[i, k] * B[k, j]
                                    end
                                end
                            end
                        end)
                        @finch begin
                            Ct .= 0
                            for i = parallel(_)
                                for j = _
                                    for k = _
                                        Ct[i, j] += A[i, k] * B[k, j]
                                    end
                                end
                            end
                        end

                        @test Ct == CR

                        check_output("parallel/debug_spmm_no_atomics_$fmtA1_$fmtA2_2.txt", @finch_code begin
                            Ct .= 0
                            for i = _
                                for j = parallel(_)
                                    for k = _
                                        Ct[i, j] += A[i, k] * B[k, j]
                                    end
                                end
                            end
                        end)
                        @finch begin
                            Ct .= 0
                            for i = _
                                for j = parallel(_)
                                    for k = _
                                        Ct[i, j] += A[i, k] * B[k, j]
                                    end
                                end
                            end
                        end

                        @test Ct == CR

                        check_output("parallel/debug_spmm_no_atomics_$fmtA1_$fmtA2_3.txt", @finch_code begin
                            Ct .= 0
                            for i = _
                                for j = _
                                    for k = parallel(_)
                                        Ct[i, j] += A[i, k] * B[k, j]
                                    end
                                end
                            end
                        end)
                        @finch begin
                            Ct .= 0
                            for i = _
                                for j = _
                                    for k = parallel(_)
                                        Ct[i, j] += A[i, k] * B[k, j]
                                    end
                                end
                            end
                        end

                        @test Ct == CR

                        check_output("parallel/debug_spmm_no_atomics_$fmtA1_$fmtA2_4.txt", @finch_code begin
                            Ct .= 0
                            for j = parallel(_)
                                for i = _
                                    for k = _
                                        Ct[i, j] += A[i, k] * B[k, j]
                                    end
                                end
                            end
                        end)
                        @finch begin
                            Ct .= 0
                            for j = parallel(_)
                                for i = _
                                    for k = _
                                        Ct[i, j] += A[i, k] * B[k, j]
                                    end
                                end
                            end
                        end

                        @test Ct == CR

                    end
                end
            end
        end
        =#

        let
            A = fsprand(UInt, 42, 42, 0.9)
            B = fsprand(UInt, 42, 42, 0.9)
            CR = Tensor(Dense(Dense(Element(UInt(0)))), undef, 42, 42)

            check_output(
                "parallel/debug_spmm_atomics_1.txt",
                @finch_code begin
                    CR .= 0
                    for i in _
                        for j in _
                            for k in _
                                CR[i, j] += A[i, k] * B[k, j]
                            end
                        end
                    end
                end
            )

            @finch begin
                CR .= 0
                for i in _
                    for j in _
                        for k in _
                            CR[i, j] += A[i, k] * B[k, j]
                        end
                    end
                end
            end

            AFormat = SparseList(Dense(Element(UInt(0))))
            At = Tensor(AFormat, A)
            BFormat = Dense(SparseList(Element(UInt(0))))
            Bt = Tensor(BFormat, B)
            Ct = Tensor(Dense(Dense(Mutex(Element(UInt(0))))), undef, 42, 42)
            CBad = Tensor(Dense(Dense((Element(UInt(0))))), undef, 42, 42)

            #=

            @test_throws Finch.FinchConcurrencyError begin
                @finch_code begin
                    Ct .= 0
                    for i = _
                        for j = _
                            for k = parallel(_)
                                CBad[i, j] += A[i, k] * B[k, j]
                            end
                        end
                    end
                end
            end

            check_output("parallel/debug_spmm_atomics_2.txt", @finch_code begin
                Ct .= 0
                for i = _
                    for j = _
                        for k = parallel(_)
                            Ct[i, j] += A[i, k] * B[k, j]
                        end
                    end
                end
            end)

            @finch begin
                Ct .= 0
                for i = _
                for k = parallel(_)
                    for j = _
                    Ct[i, j] += A[i, k] * B[k, j]
                    end
                end
                end
            end

            @test Ct == CR

            check_output("parallel/debug_spmm_atomics_3.txt", @finch_code begin
                Ct .= 0
                for i = _
                    for k = parallel(_)
                        for j = _
                            Ct[i, j] += A[i, k] * B[k, j]
                        end
                    end
                end
            end)

            @test Ct == CR

            check_output("parallel/debug_spmm_atomics_4.txt", @finch_code begin
                Ct .= 0
                for k = parallel(_)
                for i = _
                    for j = _
                    Ct[i, j] += A[i, k] * B[k, j]
                    end
                end
                end
            end)

            @finch begin
                Ct .= 0
                for k = parallel(_)
                    for i = _
                        for j = _
                            Ct[i, j] += A[i, k] * B[k, j]
                        end
                    end
                end
            end

            @test Ct == CR
            =#
        end

        let
            io = IOBuffer()
            A = Tensor(Dense(SparseList(Element(0))), [1 2; 3 4])
            x = Tensor(Dense(Element(0)), [1, 1])
            y = Tensor(Dense(Mutex(Element(0))))
            @repl io @finch_code begin
                y .= 0
                for j in parallel(_)
                    for i in _
                        y[j] += x[i] * A[walk(i), j]
                    end
                end
            end

            @repl io @finch begin
                y .= 0
                for i in parallel(_)
                    for j in _
                        y[j] += x[i] * A[walk(i), j]
                    end
                end
            end

            @test check_output("parallel/parallel_spmv_atomics.txt", String(take!(io)))
        end

        let
            io = IOBuffer()

            x = Tensor(Dense(Element(0)), undef, 100)
            y = Tensor(Dense(Mutex(Element(0))), undef, 5)
            @repl io @finch_code begin
                x .= 0
                for j in _
                    x[j] = Int((j * j) % 5 + 1)
                end
                y .= 0
                for j in parallel(_)
                    y[x[j]] += 1
                end
            end
            @repl io @finch begin
                x .= 0
                for j in _
                    x[j] = Int((j * j) % 5 + 1)
                end
                y .= 0
                for j in parallel(_)
                    y[x[j]] += 1
                end
            end

            xp = Tensor(Dense(Element(Int(0))), undef, 100)
            yp = Tensor(Dense(Element(0.0)), undef, 5)

            @repl io @finch begin
                xp .= 0
                for j in _
                    xp[j] = Int((j * j) % 5 + 1)
                end
                yp .= 0
                for j in _
                    yp[x[j]] += 1
                end
            end

            @test yp == y

            @test check_output("parallel/stress_dense_atomics.txt", String(take!(io)))
        end

        let
            A = Tensor(Dense(SparseList(Element(0.0))))
            x = Tensor(Dense(Element(0.0)))
            y = Tensor(Dense(Element(0.0)))
            @test_throws Finch.FinchConcurrencyError begin
                @finch_code begin
                    y .= 0
                    for j in parallel(_)
                        for i in _
                            y[i + j] += x[i] * A[walk(i), j]
                        end
                    end
                end
            end
        end

        let
            A = Tensor(Dense(SparseList(Element(0.0))))
            x = Tensor(Dense(Element(0.0)))
            y = Tensor(Dense(Element(0.0)))

            @test_throws Finch.FinchConcurrencyError begin
                @finch_code begin
                    y .= 0
                    for j in parallel(_)
                        for i in _
                            y[i] += x[i] * A[walk(i), j]
                            y[i + 1] += x[i] * A[walk(i), j]
                        end
                    end
                end
            end
        end

        let
            A = Tensor(Dense(SparseList(Element(0.0))))
            x = Tensor(Dense(Element(0.0)))
            y = Tensor(Dense(Element(0.0)))

            @test_throws Finch.EnforceLifecyclesError begin
                @finch_code begin
                    y .= 0
                    for j in parallel(_)
                        for i in _
                            y[i] += x[i] * A[walk(i), j]
                            y[i + 1] *= x[i] * A[walk(i), j]
                        end
                    end
                end
            end
        end

        #https://github.com/finch-tensor/Finch.jl/issues/317
        let
            A = rand(5, 5)
            B = rand(5, 5)

            @test_throws Finch.FinchConcurrencyError begin
                @finch_code begin
                    for j in _
                        for i in parallel(_)
                            B[i, j] = A[i, j]
                            B[i + 1, j] = A[i, j]
                        end
                    end
                end
            end
        end

        let
            # Computes a horizontal blur a row at a time
            input = Tensor(Dense(Dense(Element(0.0))))
            output = Tensor(Dense(Dense(Element(0.0))))
            Cpu = cpu(Threads.nthreads())
            tmp = transfer(Finch.CPULocalMemory(Cpu), Tensor(Dense(Element(0))))

            check_output(
                "parallel/parallel_blur.jl",
                @finch_code begin
                    output .= 0
                    for y in parallel(_, Cpu)
                        tmp .= 0
                        for x in _
                            tmp[x] += input[x - 1, y] + input[x, y] + input[x + 1, y]
                        end

                        for x in _
                            output[x, y] = tmp[x]
                        end
                    end
                end
            )
        end

        let
            # Computes a horizontal blur a row at a time
            input = Tensor(Dense(SparseList(Element(0.0))))
            output = Tensor(Dense(Dense(Element(0.0))))
            Cpu = cpu(Threads.nthreads())
            tmp = transfer(Finch.CPULocalMemory(Cpu), Tensor(Dense(Element(0))))

            check_output(
                "parallel/parallel_blur_sparse.jl",
                @finch_code begin
                    output .= 0
                    for y in parallel(_, Cpu)
                        tmp .= 0
                        for x in _
                            tmp[x] += input[x - 1, y] + input[x, y] + input[x + 1, y]
                        end

                        for x in _
                            output[x, y] = tmp[x]
                        end
                    end
                end
            )
        end

        let
            y = Tensor(Dense(Mutex(Element(0.0))))
            A = Tensor(Dense(SparseList(Element(0.0))))
            x = Tensor(Dense(Element(0.0)))
            diag = Tensor(Dense(Element(0.0)))
            y_j = Scalar(0.0)
            @test check_output(
                "parallel/atomics_sym_spmv.txt", @finch_code begin
                    y .= 0
                    for j in parallel(_)
                        let x_j = x[j]
                            y_j .= 0
                            for i in _
                                let A_ij = A[i, j]
                                    y[i] += x_j * A_ij
                                    y_j[] += A_ij * x[i]
                                end
                            end
                            y[j] += y_j[] + diag[j] * x_j
                        end
                    end
                end
            )
        end

        let
            A = Tensor(Dense(SparseList(Element(0.0))), fsprand(UInt, 42, 42, 0.1))
            x = Tensor(Dense(Element(0.0)), rand(UInt, 42))
            y = Tensor(Dense(AtomicElement(0.0)))

            check_output(
                "parallel/parallel_spmv_atomic.txt", @finch_code begin
                    y .= 0
                    for j in parallel(_)
                        for i in _
                            y[i] += A[i, j] * x[j]
                        end
                    end
                end
            )

            @finch begin
                y .= 0
                for j in parallel(_)
                    for i in _
                        y[i] += A[i, j] * x[j]
                    end
                end
            end

            @test norm(y - A * x) / norm(A * x) < 1e-10
        end

        #https://github.com/finch-tensor/Finch.jl/pull/668
        let
            A = Tensor(Dense(SparseList(Element(0.0))), fsprand(UInt, 42, 42, 0.1))
            x = Tensor(Dense(Element(0.0)), rand(UInt, 42))
            y = Tensor(Dense(Mutex(Element(0.0))))

            @finch begin
                y .= 0
                for j in parallel(_)
                    for i in _
                        y[i] += A[i, j] * x[j]
                    end
                end
            end

            @test norm(y - A * x) / norm(A * x) < 1e-10
        end

        let
            A = Tensor(Dense(SparseList(Element(0.0))), fsprand(UInt, 42, 42, 0.1))
            x = Tensor(Dense(Element(0.0)), rand(UInt, 42))
            y = Tensor(Dense(Separate(Element(0.0))))

            @finch begin
                y .= 0
                for i in parallel(_)
                    for j in _
                        y[i] += A[j, i] * x[j]
                    end
                end
            end

            @test norm(y - permutedims(A) * x) / norm(permutedims(A) * x) < 1e-10
        end

        # Check that passing static_schedule() as argument to parallel is working
        let
            A = Tensor(Dense(SparseList(Element(0.0))), fsprand(UInt, 42, 42, 0.1))
            x = Tensor(Dense(Element(0.0)), rand(UInt, 42))
            y = Tensor(Dense(Element(0.0)))

            @finch begin
                y .= 0
                for j in parallel(_, cpu(Threads.nthreads()), static_schedule())
                    for i in _
                        y[j] += A[i, j] * x[i]
                    end
                end
            end

            y_ref = swizzle(A, 2, 1) * x
            @test norm(y - y_ref) / norm(y_ref) < 1e-10
        end

        let
            A = Tensor(Dense(SparseList(Element(0.0))), fsprand(UInt, 42, 42, 0.1))
            x = Tensor(Dense(Element(0.0)), rand(UInt, 42))
            y = Tensor(Dense(Element(0.0)))

            @finch begin
                y .= 0
                for j in parallel(_, cpu(Threads.nthreads()), static_schedule(:dynamic))
                    for i in _
                        y[j] += A[i, j] * x[i]
                    end
                end
            end

            y_ref = swizzle(A, 2, 1) * x
            @test norm(y - y_ref) / norm(y_ref) < 1e-10
        end

        # Check that passing greedy_schedule as argument to parallel is working
        let
            A = Tensor(Dense(SparseList(Element(0.0))), fsprand(UInt, 42, 42, 0.1))
            x = Tensor(Dense(Element(0.0)), rand(UInt, 42))
            y = Tensor(Dense(Element(0.0)))

            @finch begin
                y .= 0
                for j in parallel(_, cpu(Threads.nthreads()), greedy_schedule(4))
                    for i in _
                        y[j] += A[i, j] * x[i]
                    end
                end
            end

            y_ref = swizzle(A, 2, 1) * x
            @test norm(y - y_ref) / norm(y_ref) < 1e-10
        end

        let
            A = Tensor(Dense(SparseList(Element(0.0))), fsprand(UInt, 42, 42, 0.1))
            x = Tensor(Dense(Element(0.0)), rand(UInt, 42))
            y = Tensor(Dense(Element(0.0)))

            @finch begin
                y .= 0
                for j in parallel(_, cpu(Threads.nthreads()), greedy_schedule(4, :dynamic))
                    for i in _
                        y[j] += A[i, j] * x[i]
                    end
                end
            end

            y_ref = swizzle(A, 2, 1) * x
            @test norm(y - y_ref) / norm(y_ref) < 1e-10
        end

        # Check that passing julia_schedule as argument to parallel is working
        let
            A = Tensor(Dense(SparseList(Element(0.0))), fsprand(UInt, 42, 42, 0.1))
            x = Tensor(Dense(Element(0.0)), rand(UInt, 42))
            y = Tensor(Dense(Element(0.0)))

            @finch begin
                y .= 0
                for j in parallel(_, cpu(Threads.nthreads()), julia_schedule(4))
                    for i in _
                        y[j] += A[i, j] * x[i]
                    end
                end
            end

            y_ref = swizzle(A, 2, 1) * x
            @test norm(y - y_ref) / norm(y_ref) < 1e-10
        end

        let
            A = Tensor(Dense(SparseList(Element(0.0))), fsprand(UInt, 42, 42, 0.1))
            x = Tensor(Dense(Element(0.0)), rand(UInt, 42))
            y = Tensor(Dense(Element(0.0)))

            @finch begin
                y .= 0
                for j in parallel(_, cpu(Threads.nthreads()), julia_schedule(4, :dynamic))
                    for i in _
                        y[j] += A[i, j] * x[i]
                    end
                end
            end

            y_ref = swizzle(A, 2, 1) * x
            @test norm(y - y_ref) / norm(y_ref) < 1e-10
        end
    end
end
