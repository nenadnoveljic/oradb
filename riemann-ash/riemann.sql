/*
 * Author: Nenad Noveljic
 * v1.0
 */

column begin_interval_time new_value begin_ts
column end_interval_time new_value end_ts

alter session set nls_timestamp_format='dd/mm/yyyy hh24:mi:ss.ff' ;

prompt dbtime
select begin_interval_time, end_interval_time,
  round(
    (value - lead( value, 1 ) over (order by begin_interval_time desc ) ) / 1e6
  ) dbtime
  from dba_hist_sys_time_model t, dba_hist_snapshot s
  where s.snap_id = t.snap_id and t.stat_name = 'DB time'
  order by begin_interval_time desc
  fetch first 1 rows only ;

prompt left Riemann sum
select count(*) from v$active_session_history
  where
    sample_time between
      to_timestamp('&begin_ts') and
      to_timestamp('&end_ts')
    and session_type != 'BACKGROUND'
;
