#!/bin/bash
#########################################################
## shsnc
## check timesten middle table
## 2016/11/14
## example :
##   eg1 : sh tt_midtab_check.sh
##   eg2 : sh tt_midtab_check.sh 2 10
##   eg3 : sh tt_midtab_check.sh 2 10 HB_ODS TT_03_7701988_L
############################################################
i=1
test $1
if [ $? = 0 ]; then
  rt=$1
  test $2
  if [ $? = 0 ]; then
    il=$2  
  fi
else
  rt=1
  il=1
fi
test $3 && test $4
if [ $? = 0 ]; then
  TO=$3
  TN=$4
else
  TO='TO'
  TN='TN'
fi
tt_logtab_check(){
sqlplus -s / as sysdba <<EOF
set linesize 999
set heading off
set serverout on
set feedback off
declare
  v_table_owner  varchar2(30);
  v_table_name   varchar2(30);
  v_table_rowcnt number;
  g_table_rowcnt number;
  v_table_size   number;
  g_table_size   number;
  v_index_size   number;
  g_index_size   number;
  v_sql          varchar2(2000);
  log_date       date;
  l_elapsed_int  INTERVAL DAY(3) TO SECOND(3);
  cursor cur_base_table_name is
    select tuc.base_tab_owner,
           REGEXP_SUBSTR(tuc.base_tab, '[^.]+', 1, 2) base_tab_name,
           tuc.base_tab_id,
           dt.owner mid_tab_owner,
           dt.table_name mid_tab_name
      from dba_tables dt,
           (select distinct REGEXP_SUBSTR(TABLENAME, '[^.]+', 1, 1) base_tab_owner,
                            TABLENAME base_tab,
                            object_id base_tab_id
              from RS_SM.tt_03_user_count
            union
            select distinct REGEXP_SUBSTR(TABLENAME, '[^.]+', 1, 1) base_tab_owner,
                            TABLENAME base_tab,
                            object_id base_tab_id
              from OCS_CM.tt_03_user_count
            union
            select distinct REGEXP_SUBSTR(TABLENAME, '[^.]+', 1, 1) base_tab_owner,
                            TABLENAME base_tab,
                            object_id base_tab_id
              from HB_OCS_SM.tt_03_user_count
            union
            select distinct REGEXP_SUBSTR(TABLENAME, '[^.]+', 1, 1) base_tab_owner,
                            TABLENAME base_tab,
                            object_id base_tab_id
              from RS_ODS.tt_03_user_count
            union
            select distinct REGEXP_SUBSTR(TABLENAME, '[^.]+', 1, 1) base_tab_owner,
                            TABLENAME base_tab,
                            object_id base_tab_id
              from HB_ODS.tt_03_user_count) tuc
     where REGEXP_SUBSTR(dt.table_name, '[^_]+', 1, 3) = tuc.base_tab_id
       and table_name like 'TT_03_%L'
      ;-- and rownum<4;
      -- and table_name = 'TT_03_5830425_L'; --rownum < 5;
  function get_table_rowcnt(I_OWNER        IN VARCHAR2,
                            I_TABLE_NAME   IN VARCHAR2,
                            I_TABLE_ROWCNT OUT NUMBER) RETURN NUMBER IS
    l_table_rowcnt number;
    l_owner        varchar2(20);
    l_table_name   varchar2(255);
    v_sql          varchar2(2000);
  begin
    l_owner      := I_OWNER;
    l_table_name := I_TABLE_NAME;
    v_sql        := 'select count(1) from ' || I_OWNER || '.' ||
                    I_TABLE_NAME;
    EXECUTE IMMEDIATE v_sql
      INTO v_table_rowcnt;
    return v_table_rowcnt;
  EXCEPTION
    WHEN OTHERS THEN
      v_table_rowcnt := -1;
      return v_table_rowcnt;
  end;

  function get_table_size(I_OWNER      IN VARCHAR2,
                          I_TABLE_NAME IN VARCHAR2,
                          I_TABLE_size OUT NUMBER) RETURN NUMBER IS
    l_table_size number;
    l_owner      varchar2(20);
    l_table_name varchar2(255);
    v_sql        varchar2(2000);
  begin
    l_owner      := I_OWNER;
    l_table_name := I_TABLE_NAME;
    v_sql        := '
    select sum(bytes / 1024 /1024) as SIZE_MB
  from dba_segments
 where OWNER = ''' || I_OWNER || '''
   and SEGMENT_NAME = ''' || I_TABLE_NAME || '''
 group by OWNER, SEGMENT_NAME';
    EXECUTE IMMEDIATE v_sql
      INTO v_table_size;
    return v_table_size;
  EXCEPTION
    WHEN OTHERS THEN
      v_table_size := -1;
      return v_table_size;
  end;

  function get_index_size(I_OWNER      IN VARCHAR2,
                          I_INDEX_NAME IN VARCHAR2,
                          I_INDEX_SIZE OUT NUMBER) RETURN NUMBER IS
    l_index_size number;
    l_owner      varchar2(20);
    l_index_name varchar2(255);
    v_sql        varchar2(2000);
  begin
    l_owner      := I_OWNER;
    l_index_name := I_INDEX_NAME;
    v_sql        := '
    select sum(bytes / 1024 /1024) as SIZE_MB
  from dba_segments
 where OWNER = ''' || I_OWNER || '''
   and SEGMENT_NAME = ''' || I_INDEX_NAME || '''
 group by OWNER, SEGMENT_NAME';
    EXECUTE IMMEDIATE v_sql
      INTO v_index_size;
    return v_index_size;
  EXCEPTION
    WHEN OTHERS THEN
      v_index_size := -1;
      return v_index_size;
  end;
  procedure get_table_statis(I_MID_TAB_OWNER  IN VARCHAR2,
                             I_MID_TAB_NAME   IN VARCHAR2,
                             I_LOG_DATE       IN date,
                             I_BASE_TAB_ID    IN VARCHAR2,
                             I_BASE_TAB_OWNER IN VARCHAR2,
                             I_BASE_TAB_NAME  IN VARCHAR2,
                             I_MID_TAB_ID     IN NUMBER default null,
                             P_ELAPSED_INT    OUT INTERVAL DAY TO SECOND) IS
    l_mid_tab_owner    varchar2(20);
    l_mid_tab_name     varchar2(255);
    l_mid_tab_rowcnt   number;
    l_mid_tab_size     number;
    l_mid_tab_idx_size number;
    l_log_date         date;
    l_base_tab_name    varchar(128);
    l_base_tab_owner   varchar(128);
    l_base_tab_id      number;
    l_date_b           timestamp(6);
    l_date_e           timestamp(6);
    l_elapsed_int      INTERVAL DAY(3) TO SECOND(3);
  begin
    l_mid_tab_owner  := I_MID_TAB_OWNER;
    l_mid_tab_name   := I_MID_TAB_NAME;
    l_base_tab_name  := I_BASE_TAB_NAME;
    l_base_tab_owner := I_BASE_TAB_OWNER;
    l_base_tab_id    := I_BASE_TAB_ID;
    l_log_date       := I_LOG_DATE;
    l_date_b         := systimestamp; 
    g_table_rowcnt   := get_table_rowcnt(l_mid_tab_owner,
                                         l_mid_tab_name,
                                         l_mid_tab_rowcnt);
    l_date_e         := systimestamp; 
    l_elapsed_int    := l_date_e - l_date_b;
    P_ELAPSED_INT    := l_elapsed_int;
    g_table_size     := get_table_size(l_mid_tab_owner,
                                       l_mid_tab_name,
                                       l_mid_tab_size);
    g_index_size     := get_index_size(l_mid_tab_owner,
                                       l_mid_tab_name || 'L',
                                       l_mid_tab_idx_size);
    insert into snc_test.tt_logtab_check(
       LOG_DATE          ,
       SAM_DATE          ,
       BASE_TAB_NAME,
       BASE_TAB_OWNER,
       BASE_TAB_ID,
       MID_TAB_NAME,
       MID_TAB_OWNER,
       MID_TAB_ID,
       MID_TAB_SIZE,
       MID_TAB_ROWCNT,
       MID_TAB_IDX_NAME,
       MID_TAB_IDX_OWNER,
       MID_TAB_IND_SIZE,
       ELAPSED_INTERVAL
       )
    values
      (l_log_date,
       sysdate,
       l_base_tab_name,
       l_base_tab_owner,
       l_base_tab_id,
       l_mid_tab_name,
       l_mid_tab_owner,
       null,
       g_table_size,
       g_table_rowcnt,
       l_mid_tab_name || 'L',
       l_mid_tab_owner,
       g_index_size,
       l_elapsed_int);
    commit;
  EXCEPTION
    WHEN OTHERS THEN
      dbms_output.put_line(sqlerrm);
  end;
begin
  log_date := sysdate;
  for cur_btn in cur_base_table_name loop
    if '${TO}' = 'TO' and '${TN}' = 'TN' then
      --dbms_output.put_line('    ....'||rpad(cur_base_table_name%ROWCOUNT,5,'.')||'  '||to_char(sysdate,'yyyymmdd hh24:mi:ss')||'  '||cur_btn.mid_tab_owner||'.'||cur_btn.mid_tab_name);
      --dbms_output.put_line('    ....'||rpad(cur_base_table_name%ROWCOUNT,5,'.')||'  '||to_char(sysdate,'yyyymmdd hh24:mi:ss')||'  '||l_elapsed_int||'  '||cur_btn.mid_tab_owner||'.'||cur_btn.mid_tab_name);
      get_table_statis(I_MID_TAB_OWNER  => cur_btn.mid_tab_owner,
                       I_MID_TAB_NAME   => cur_btn.mid_tab_name,
                       I_LOG_DATE       => log_date,
                       I_BASE_TAB_ID    => cur_btn.base_tab_id,
                       I_BASE_TAB_OWNER => cur_btn.base_tab_owner,
                       I_BASE_TAB_NAME  => cur_btn.base_tab_name,
                       I_MID_TAB_ID     => null,
                       P_ELAPSED_INT    => l_elapsed_int); 
      dbms_output.put_line('    ....'||rpad(cur_base_table_name%ROWCOUNT,5,'.')||'  '||to_char(sysdate,'yyyymmdd hh24:mi:ss')||'  '||l_elapsed_int||'  '||cur_btn.mid_tab_owner||'.'||cur_btn.mid_tab_name);
    elsif '${TO}' = cur_btn.mid_tab_owner and '${TN}' = cur_btn.mid_tab_name then
      --dbms_output.put_line('    .... '||to_char(sysdate,'yyyymmdd hh24:mi:ss')||'  '||cur_btn.mid_tab_owner||'.'||cur_btn.mid_tab_name);
      get_table_statis(I_MID_TAB_OWNER  => '${TO}',
                       I_MID_TAB_NAME   => '${TN}',
                       I_LOG_DATE       => log_date,
                       I_BASE_TAB_ID    => cur_btn.base_tab_id,
                       I_BASE_TAB_OWNER => cur_btn.base_tab_owner,
                       I_BASE_TAB_NAME  => cur_btn.base_tab_name,
                       I_MID_TAB_ID     => null,
                       P_ELAPSED_INT    => l_elapsed_int); 
      dbms_output.put_line('    .... '||to_char(sysdate,'yyyymmdd hh24:mi:ss')||' '||l_elapsed_int||'  '||cur_btn.mid_tab_owner||'.'||cur_btn.mid_tab_name);
      exit;
    end if;
    -- dbms_output.put_line($1);
  end loop;
  commit;
end;
/
exit
EOF
}
# arg1=start, arg2=end, format: %s.%N  
getTiming() {  
    start=$1  
    end=$2  
    start_s=$(echo $start | cut -d '.' -f 1)  
    start_ns=$(echo $start | cut -d '.' -f 2)  
    end_s=$(echo $end | cut -d '.' -f 1)  
    end_ns=$(echo $end | cut -d '.' -f 2)  
    time=$(( ( 10#$end_s - 10#$start_s ) * 1000 + ( 10#$end_ns / 1000000 - 10#$start_ns / 1000000 ) ))  
    #echo "$time ms"  
    echo `expr $time / 1000` s
}  
tt_logtab_show(){
sqlplus -s / as sysdba <<EOF
set heading off
set serverout on
set feedback off
set linesize 10000 pagesize 9999
col logdate for a18
col samdate for a18
col base_tab  for a38
col mid_tab  for a30
col mid_tab_idx for a28
col mid_tab_size for 999999.999
col mid_tab_ind_size for 999999.999
col ro for 999
col ei for a17
col elapsed_interval for a17
col rowcnt for 9999999
col tabsize for 9999.9
col idxsize for 9999.9
break on base_tab on mid_tab on startup_time skip 1
break on base_tab on mid_tab on mid_tab_rowcnt on MID_TAB_SIZE on MID_TAB_IDX on MID_TAB_IND_SIZE on startup_time skip 3  
select base_tab,
       mid_tab,
       mid_tab_rowcnt rowcnt,
       mid_tab_size tabsize,
       mid_tab_idx,
       mid_tab_ind_size idxsize,
       ro,
       samlate,
       elapsed_interval
  from (select --to_char(log_date, 'yyyymmdd hh24:mi:ss') logdate,
         base_tab_owner || '.' || base_tab_name base_tab,
         mid_tab_owner || '.' || mid_tab_name mid_tab,
         mid_tab_rowcnt,
         mid_tab_size,
         mid_tab_idx_owner || '.' || mid_tab_idx_name mid_tab_idx,
         mid_tab_ind_size,
         dense_rank() over(PARTITION BY mid_tab_owner || '.' || mid_tab_name ORDER BY mid_tab_rowcnt) ro,
         to_char(sam_date, 'yyyymmdd hh24:mi:ss') samlate,elapsed_interval
          from (select *
                  from snc_test.TT_LOGTAB_CHECK
                 where log_date >
                       to_date('2016-12-11 00:00:00', 'yyyy-mm-dd hh24:mi:ss')
                   and mid_tab_rowcnt > 500
                   -- and base_tab_name=''
                   -- and mid_tab_name='TT_03_533537_L'
                   )
         order by 2, 8)
 where ro > 1;  
/
exit
EOF
}
while [ "$i" -le "${rt}" ]
 do
  start=$(date +%s.%N)
  echo Begin ${i} --`date`-----
  tt_logtab_check
  #tt_logtab_show
  end=$(date +%s.%N) 
  #getTiming $start $end  
  echo -`getTiming $start $end `----- ${i} -- `date` End 
  sleep ${il}
  i=`expr $i + 1`
done
