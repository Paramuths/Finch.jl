begin
    res_lvl = (ex.bodies[1]).tns.bind.lvl
    res_lvl_ptr = res_lvl.ptr
    res_lvl_idx = res_lvl.idx
    res_lvl_2 = res_lvl.lvl
    res_lvl_ptr_2 = res_lvl_2.ptr
    res_lvl_idx_2 = res_lvl_2.idx
    res_lvl_3 = res_lvl_2.lvl
    res_lvl_2_val = res_lvl_2.lvl.val
    tmp_lvl = (ex.bodies[2]).body.body.rhs.tns.bind.lvl
    tmp_lvl_ptr = (ex.bodies[2]).body.body.rhs.tns.bind.lvl.ptr
    tmp_lvl_tbl1 = (ex.bodies[2]).body.body.rhs.tns.bind.lvl.tbl[1]
    tmp_lvl_tbl2 = (ex.bodies[2]).body.body.rhs.tns.bind.lvl.tbl[2]
    tmp_lvl_val = tmp_lvl.lvl.val
    res_lvl_qos_stop = 0
    res_lvl_2_qos_fill = 0
    res_lvl_2_qos_stop = 0
    res_lvl_2_prev_pos = 0
    Finch.resize_if_smaller!(res_lvl_ptr, 1 + 1)
    Finch.fill_range!(res_lvl_ptr, 0, 1 + 1, 1 + 1)
    res_lvl_qos = 0 + 1
    0 < 1 || throw(FinchProtocolError("SparseListLevels cannot be updated multiple times"))
    tmp_lvl_q = tmp_lvl_ptr[1]
    tmp_lvl_q_stop = tmp_lvl_ptr[1 + 1]
    if tmp_lvl_q < tmp_lvl_q_stop
        tmp_lvl_i_stop = tmp_lvl_tbl2[tmp_lvl_q_stop - 1]
    else
        tmp_lvl_i_stop = 0
    end
    phase_stop = min(tmp_lvl_i_stop, tmp_lvl.shape[2])
    if phase_stop >= 1
        if tmp_lvl_tbl2[tmp_lvl_q] < 1
            tmp_lvl_q = Finch.scansearch(tmp_lvl_tbl2, 1, tmp_lvl_q, tmp_lvl_q_stop - 1)
        end
        while true
            tmp_lvl_i = tmp_lvl_tbl2[tmp_lvl_q]
            tmp_lvl_q_step = tmp_lvl_q
            if tmp_lvl_tbl2[tmp_lvl_q] == tmp_lvl_i
                tmp_lvl_q_step = Finch.scansearch(tmp_lvl_tbl2, tmp_lvl_i + 1, tmp_lvl_q, tmp_lvl_q_stop - 1)
            end
            if tmp_lvl_i < phase_stop
                if res_lvl_qos > res_lvl_qos_stop
                    res_lvl_qos_stop = max(res_lvl_qos_stop << 1, 1)
                    Finch.resize_if_smaller!(res_lvl_idx, res_lvl_qos_stop)
                    Finch.resize_if_smaller!(res_lvl_ptr_2, res_lvl_qos_stop + 1)
                    Finch.fill_range!(res_lvl_ptr_2, 0, res_lvl_qos + 1, res_lvl_qos_stop + 1)
                end
                res_lvldirty = false
                res_lvl_2_qos = res_lvl_2_qos_fill + 1
                res_lvl_2_prev_pos < res_lvl_qos || throw(FinchProtocolError("SparseListLevels cannot be updated multiple times"))
                tmp_lvl_q_2 = tmp_lvl_q
                if tmp_lvl_q < tmp_lvl_q_step
                    tmp_lvl_i_stop_2 = tmp_lvl_tbl1[tmp_lvl_q_step - 1]
                else
                    tmp_lvl_i_stop_2 = 0
                end
                phase_stop_3 = min(tmp_lvl_i_stop_2, tmp_lvl.shape[1])
                if phase_stop_3 >= 1
                    if tmp_lvl_tbl1[tmp_lvl_q] < 1
                        tmp_lvl_q_2 = Finch.scansearch(tmp_lvl_tbl1, 1, tmp_lvl_q, tmp_lvl_q_step - 1)
                    end
                    while true
                        tmp_lvl_i_2 = tmp_lvl_tbl1[tmp_lvl_q_2]
                        if tmp_lvl_i_2 < phase_stop_3
                            tmp_lvl_2_val = tmp_lvl_val[tmp_lvl_q_2]
                            if res_lvl_2_qos > res_lvl_2_qos_stop
                                res_lvl_2_qos_stop = max(res_lvl_2_qos_stop << 1, 1)
                                Finch.resize_if_smaller!(res_lvl_idx_2, res_lvl_2_qos_stop)
                                Finch.resize_if_smaller!(res_lvl_2_val, res_lvl_2_qos_stop)
                                Finch.fill_range!(res_lvl_2_val, false, res_lvl_2_qos, res_lvl_2_qos_stop)
                            end
                            res = (res_lvl_2_val[res_lvl_2_qos] = tmp_lvl_2_val)
                            res_lvldirty = true
                            res_lvl_idx_2[res_lvl_2_qos] = tmp_lvl_i_2
                            res_lvl_2_qos += 1
                            res_lvl_2_prev_pos = res_lvl_qos
                            tmp_lvl_q_2 += 1
                        else
                            phase_stop_5 = min(tmp_lvl_i_2, phase_stop_3)
                            if tmp_lvl_i_2 == phase_stop_5
                                tmp_lvl_2_val = tmp_lvl_val[tmp_lvl_q_2]
                                if res_lvl_2_qos > res_lvl_2_qos_stop
                                    res_lvl_2_qos_stop = max(res_lvl_2_qos_stop << 1, 1)
                                    Finch.resize_if_smaller!(res_lvl_idx_2, res_lvl_2_qos_stop)
                                    Finch.resize_if_smaller!(res_lvl_2_val, res_lvl_2_qos_stop)
                                    Finch.fill_range!(res_lvl_2_val, false, res_lvl_2_qos, res_lvl_2_qos_stop)
                                end
                                res_lvl_2_val[res_lvl_2_qos] = tmp_lvl_2_val
                                res_lvldirty = true
                                res_lvl_idx_2[res_lvl_2_qos] = phase_stop_5
                                res_lvl_2_qos += 1
                                res_lvl_2_prev_pos = res_lvl_qos
                                tmp_lvl_q_2 += 1
                            end
                            break
                        end
                    end
                end
                res_lvl_ptr_2[res_lvl_qos + 1] = (res_lvl_2_qos - res_lvl_2_qos_fill) - 1
                res_lvl_2_qos_fill = res_lvl_2_qos - 1
                if res_lvldirty
                    res_lvl_idx[res_lvl_qos] = tmp_lvl_i
                    res_lvl_qos += 1
                end
                tmp_lvl_q = tmp_lvl_q_step
            else
                phase_stop_7 = min(tmp_lvl_i, phase_stop)
                if tmp_lvl_i == phase_stop_7
                    if res_lvl_qos > res_lvl_qos_stop
                        res_lvl_qos_stop = max(res_lvl_qos_stop << 1, 1)
                        Finch.resize_if_smaller!(res_lvl_idx, res_lvl_qos_stop)
                        Finch.resize_if_smaller!(res_lvl_ptr_2, res_lvl_qos_stop + 1)
                        Finch.fill_range!(res_lvl_ptr_2, 0, res_lvl_qos + 1, res_lvl_qos_stop + 1)
                    end
                    res_lvldirty = false
                    res_lvl_2_qos_2 = res_lvl_2_qos_fill + 1
                    res_lvl_2_prev_pos < res_lvl_qos || throw(FinchProtocolError("SparseListLevels cannot be updated multiple times"))
                    tmp_lvl_q_2 = tmp_lvl_q
                    if tmp_lvl_q < tmp_lvl_q_step
                        tmp_lvl_i_stop_2 = tmp_lvl_tbl1[tmp_lvl_q_step - 1]
                    else
                        tmp_lvl_i_stop_2 = 0
                    end
                    phase_stop_8 = min(tmp_lvl_i_stop_2, tmp_lvl.shape[1])
                    if phase_stop_8 >= 1
                        if tmp_lvl_tbl1[tmp_lvl_q] < 1
                            tmp_lvl_q_2 = Finch.scansearch(tmp_lvl_tbl1, 1, tmp_lvl_q, tmp_lvl_q_step - 1)
                        end
                        while true
                            tmp_lvl_i_2 = tmp_lvl_tbl1[tmp_lvl_q_2]
                            if tmp_lvl_i_2 < phase_stop_8
                                tmp_lvl_2_val_2 = tmp_lvl_val[tmp_lvl_q_2]
                                if res_lvl_2_qos_2 > res_lvl_2_qos_stop
                                    res_lvl_2_qos_stop = max(res_lvl_2_qos_stop << 1, 1)
                                    Finch.resize_if_smaller!(res_lvl_idx_2, res_lvl_2_qos_stop)
                                    Finch.resize_if_smaller!(res_lvl_2_val, res_lvl_2_qos_stop)
                                    Finch.fill_range!(res_lvl_2_val, false, res_lvl_2_qos_2, res_lvl_2_qos_stop)
                                end
                                res_lvl_2_val[res_lvl_2_qos_2] = tmp_lvl_2_val_2
                                res_lvldirty = true
                                res_lvl_idx_2[res_lvl_2_qos_2] = tmp_lvl_i_2
                                res_lvl_2_qos_2 += 1
                                res_lvl_2_prev_pos = res_lvl_qos
                                tmp_lvl_q_2 += 1
                            else
                                phase_stop_10 = min(tmp_lvl_i_2, phase_stop_8)
                                if tmp_lvl_i_2 == phase_stop_10
                                    tmp_lvl_2_val_2 = tmp_lvl_val[tmp_lvl_q_2]
                                    if res_lvl_2_qos_2 > res_lvl_2_qos_stop
                                        res_lvl_2_qos_stop = max(res_lvl_2_qos_stop << 1, 1)
                                        Finch.resize_if_smaller!(res_lvl_idx_2, res_lvl_2_qos_stop)
                                        Finch.resize_if_smaller!(res_lvl_2_val, res_lvl_2_qos_stop)
                                        Finch.fill_range!(res_lvl_2_val, false, res_lvl_2_qos_2, res_lvl_2_qos_stop)
                                    end
                                    res_lvl_2_val[res_lvl_2_qos_2] = tmp_lvl_2_val_2
                                    res_lvldirty = true
                                    res_lvl_idx_2[res_lvl_2_qos_2] = phase_stop_10
                                    res_lvl_2_qos_2 += 1
                                    res_lvl_2_prev_pos = res_lvl_qos
                                    tmp_lvl_q_2 += 1
                                end
                                break
                            end
                        end
                    end
                    res_lvl_ptr_2[res_lvl_qos + 1] = (res_lvl_2_qos_2 - res_lvl_2_qos_fill) - 1
                    res_lvl_2_qos_fill = res_lvl_2_qos_2 - 1
                    if res_lvldirty
                        res_lvl_idx[res_lvl_qos] = phase_stop_7
                        res_lvl_qos += 1
                    end
                    tmp_lvl_q = tmp_lvl_q_step
                end
                break
            end
        end
    end
    res_lvl_ptr[1 + 1] = (res_lvl_qos - 0) - 1
    for p = 2:1 + 1
        res_lvl_ptr[p] += res_lvl_ptr[p - 1]
    end
    qos_stop = res_lvl_ptr[1 + 1] - 1
    for p_2 = 2:qos_stop + 1
        res_lvl_ptr_2[p_2] += res_lvl_ptr_2[p_2 - 1]
    end
    resize!(res_lvl_ptr, 1 + 1)
    qos = res_lvl_ptr[end] - 1
    resize!(res_lvl_idx, qos)
    resize!(res_lvl_ptr_2, qos + 1)
    qos_2 = res_lvl_ptr_2[end] - 1
    resize!(res_lvl_idx_2, qos_2)
    resize!(res_lvl_2_val, qos_2)
    (res = Fiber((SparseListLevel){Int64}((SparseListLevel){Int64}(res_lvl_3, tmp_lvl.shape[1], res_lvl_ptr_2, res_lvl_idx_2), tmp_lvl.shape[2], res_lvl_ptr, res_lvl_idx)),)
end
