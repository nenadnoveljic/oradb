/*
 * hybrid_hist_newdensity.sql
 *
 * The query calculates the new density value for hybrid histograms
 * Based on information in following blog posts:
 *   Mohamed Houri:  
 *     http://allthingsoracle.com/12c-hybrid-histogram/
 *   Nenad Noveljic: 
 *     http://nenadnoveljic.com/blog/density-calculation-hybrid-histograms
 *
 * Author: Nenad Noveljic
 *
 * Input:
 *   :table_name
 *   :column_name
 *
 * Output:
 *   NewDensity
 *
*/

with pop_v as
(
select 
    sum(endpoint_repeat_count) sum_pop_ep_rp_count ,
    count(*) pop_value_count
    from
        user_tab_histograms uth
       ,user_tab_col_statistics ucs
    where
		uth.table_name   = ucs.table_name
		and uth.column_name   = ucs.column_name
		and uth.table_name    = :table_name
		and uth.column_name   = :column_name
		and (uth.endpoint_repeat_count - ucs.sample_size/ucs.num_buckets) > 0
),
ucs_v as
( select num_distinct,sample_size from user_tab_col_statistics
    where table_name    = :table_name and column_name   = :column_name
)
select 
    ( 1 - sum_pop_ep_rp_count/sample_size)/(num_distinct - pop_value_count )
    NewDensity 
    from pop_v,ucs_v
;

