ACCEPT log_path PROMPT "Caminho para ficheiros TXT (ex: c:\temp\).........: "

SET FEEDBACK OFF;
select 'BD_' || instance_name "BD a analisar" from v$instance;
SET FEEDBACK ON;
PROMPT;
ACCEPT log_file PROMPT "Nome do ficheiro de análise (ex: bd_cliente_id)...: "

spool &log_path.&log_file..txt

prompt ______________________________________________________
prompt ______________________________________________________
prompt     Script de utilitários, CPCta, 2001.03.22
prompt
prompt					Desenvolvido por: 
prompt						Américo Santos
prompt						Paulo Quintans
prompt						Marco Martins
prompt ______________________________________________________
PROMPT
PROMPT   Anexadamente ao ficheiro &log_path.&log_file..txt
PROMPT   deverão existir:
PROMPT
PROMPT		&log_file._user_quotas_ts
PROMPT		&log_file._user_default_ts
PROMPT		&log_file._roles.txt
PROMPT		&log_file._user_num_objs.txt
PROMPT		&log_file._objs_invalidos.txt
PROMPT		&log_file._inits.txt
PROMPT ______________________________________________________
prompt   Script referente à data de:
PROMPT
select to_char(sysdate,'dd-mm-yyyy HH24:MI') from dual;
PROMPT
PROMPT ______________________________________________________

show user;

set linesize 200;
set pagesize 200;
set buffer 1000;
set arraysize 1;

select * from global_name;
select * from v$instance;
select * from v$license;

prompt ______________________________________________________
prompt  Produtos instalados 
prompt ______________________________________________________
select * from v$option;

prompt ______________________________________________________
prompt  Para ver o TIPO de tablespaces 
prompt ______________________________________________________
select tablespace_name, extent_management
from dba_tablespaces
order by tablespace_name;


prompt ______________________________________________________
prompt  Para ver o espaço TOTAL dos tablespaces 
prompt ______________________________________________________
select trunc(sum(bytes)/1024/1024) TOTAL_MB
from dba_data_files;

prompt ______________________________________________________
prompt       Tamanho MÁXIMO dos DATAFILES (BD > 8.0.5)     
prompt (INCREMENT_BY deverá multiplicar-se pelo db_block_size)
prompt ______________________________________________________
break on TABLESPACE_NAME;
SET FEEDBACK OFF;

VAR BLKSZ NUMBER
BEGIN
  SELECT TO_NUMBER(VALUE) INTO :BLKSZ FROM v$parameter where name like 'db_block_size';
END;
/

SET FEEDBACK ON;
PROMPT;

select TABLESPACE_NAME,FILE_ID,substr(FILE_NAME,1,40) datafile, AUTOEXTENSIBLE,
       trunc(BYTES/1024/1024) Tamanho, 
       trunc(INCREMENT_BY*:BLKSZ/1024/1024) Proximo, 
	trunc(MAXBYTES/1024/1024) Maximo
 from dba_data_files 
 order by 1,2;

prompt ______________________________________________________
prompt  Para ver o espaço RESERVADO para cada tablespace 
prompt ______________________________________________________
select tablespace_name, trunc(sum(bytes)/1024/1024) RESERVED_MB
from dba_data_files
group by tablespace_name;

prompt ______________________________________________________
prompt    Para ver espaço do TABLESPACE e MÁXIMO que pode crescer
prompt ______________________________________________________
select TABLESPACE_NAME, sum(trunc(BYTES/1024/1024)) Tamanho,
  sum(trunc(decode(MAXBYTES,0,bytes,maxbytes)/1024/1024)) Maximo,
  round((1-(sum(trunc(BYTES/1024/1024))/sum(trunc(decode(MAXBYTES,0,bytes,maxbytes)/1024/1024)))),2)*100 "%Livre"
 from dba_data_files
 group by tablespace_name
 order by 1;

prompt ______________________________________________________
prompt   Para ver o espaço OCUPADO por cada tablespace   
prompt ______________________________________________________
select tablespace_name, trunc(sum(bytes)/1024/1024) USED_MB
from dba_segments
group by tablespace_name;

prompt ______________________________________________________
prompt    Para ver o espaço LIVRE por cada tablespace    
prompt ______________________________________________________
select tablespace_name, trunc(sum(bytes)/1024/1024) FREE_MB
from dba_free_space
group by tablespace_name;

prompt ______________________________________________________
prompt  MÁXIMO CONTÍNUO LIVRE que o tablespace pode crescer
prompt ______________________________________________________
select TABLESPACE_NAME, trunc(max(BYTES)/1024/1024) "Livre(Mb) Contínuo"
from dba_free_space
group by tablespace_name
order by tablespace_name;

prompt ______________________________________________________
prompt          Extents que não podem crescer mais          
prompt ______________________________________________________
 select owner, segment_name, max(max_extents - extents)
 from dba_segments
 where owner not in ('SYS')
   and (max_extents - extents) < 10
 group by owner, segment_name
 order by 1,2;

prompt ______________________________________________________
prompt   Para ver os SEGMENTOS de ROLLBACK de cada tablespace    
prompt ______________________________________________________
select tablespace_name, segment_name, initial_extent/1024 "Initial Kb", 
       next_extent/1024 "Next Kb", 
       (max_extents*next_extent+initial_extent)/1024/1024 "Tamanho Máximo Mb",
	 max_extents
from dba_rollback_segs
order by 1,2;

prompt ______________________________________________________
prompt       Valores de ACESSOS aos datafiles no disco     
prompt ______________________________________________________
select substr(v$dbfile.name,1,50) Data_file, 
       v$filestat.phyrds, v$filestat.phyblkrd, 
       v$filestat.phywrts, v$filestat.phyblkwrt
from v$dbfile, v$filestat
where v$filestat.file# = v$dbfile.file#
order by 1,2,4;

prompt ______________________________________________________
prompt       Para ver ESPAÇO OCUPADO pelos utilizadores   
prompt ______________________________________________________

select owner, trunc(sum(bytes/1024/1024)) Ocupado_MB
from dba_segments
group by owner;

prompt ______________________________________________________
prompt  Para ver a DISTRIBUIÇÃO de indices e tabelas na BD 
prompt ______________________________________________________
break on OWNER;

select substr(owner,1,15) Owner, 
       substr(segment_type,1,10) Tipo,
       substr(tablespace_name,1,15) TSpace,
       trunc(sum(bytes)/1024/1024) Mb,
       count(*)
from dba_segments
group by owner, segment_type, tablespace_name
order by owner, segment_type, tablespace_name;

prompt ______________________________________________________
prompt Para VER objectos com TAMANHO > 20Mb ou INITIAL > 20Mb
prompt ______________________________________________________
break on OWNER;

select substr(owner,1,15) OWNER, substr(segment_name,1,30) Nome, 
	 segment_type, trunc(initial_extent/1024/1024) Inicial, 
	 trunc(next_extent/1024/1024) Next, 
	 trunc(bytes/1024/1024) Tamanho,
	 decode(nvl(greatest(nvl(next_extent,1),nvl(bytes,1)),1),nvl(next_extent,1),'SIM') "RESIZE"
from dba_segments
where trunc(bytes/1024/1024) >=20
   or trunc(initial_extent/1024/1024) >=20
order by owner, segment_type, segment_name;

prompt ______________________________________________________
prompt        Tabelas com PK e sem índice Unique
prompt ______________________________________________________
select OWNER, TABLE_NAME, CONSTRAINT_NAME, CONSTRAINT_TYPE, 
       R_OWNER, R_CONSTRAINT_NAME, STATUS
 from user_constraints uc
where uc.CONSTRAINT_TYPE='P'
  and uc.TABLE_NAME not in 
(select table_name
 from user_indexes 
 where table_owner = uc.owner
   and table_name = uc.table_name
   and uniqueness = 'UNIQUE');

prompt ______________________________________________________
prompt       TRIGGERS que referem tabelas de outro owner 
prompt ______________________________________________________
select table_name, table_owner, trigger_name, substr(owner,1,15) "TRIGGER OWNER", 
       SUBSTR(TRIGGERING_EVENT,1, 20) Tipo, trigger_type
from dba_triggers
where owner != table_owner;

prompt ______________________________________________________
prompt       INDICES que referem tabelas de outro owner 
prompt ______________________________________________________
select index_name, owner, table_name, substr(table_owner,1,15) "TABLE OWNER"
  from dba_indexes
 where owner != table_owner;

prompt ______________________________________________________
prompt      Objectos do SYS e SYSTEM com STATISTICS
prompt ______________________________________________________
select distinct OWNER, TABLE_NAME, trunc(LAST_ANALYZED)
  from dba_tables
 where LAST_ANALYZED is not null
   and owner in ('SYS','SYSTEM'); 

select distinct OWNER, INDEX_NAME, trunc(LAST_ANALYZED)
  from dba_index
 where LAST_ANALYZED is not null
   and owner=('SYS','SYSTEM'); 

prompt ______________________________________________________
prompt    CONSTRAINTS que referem tabelas de outro owner
prompt ______________________________________________________
select OWNER, TABLE_NAME, CONSTRAINT_NAME, CONSTRAINT_TYPE Tipo, 
       R_OWNER, R_CONSTRAINT_NAME, STATUS
  from dba_constraints
 where owner != r_owner
 order by owner, table_name, r_owner, r_constraint_name;

prompt ______________________________________________________
prompt    SINONIMOS com nomes diferentes da tabela referencia 
prompt ______________________________________________________
select 'create ' || decode(owner,'PUBLIC','PUBLIC synonym ','synonym ' || owner || '.')
       || synonym_name || ' for ' || table_owner || '.' || table_name || ';'
  from dba_synonyms
 where table_name != synonym_name
  and table_owner not in ('SYS')
  and owner not in ('SYS')
 order by owner, synonym_name, table_name;

prompt ______________________________________________________
prompt               DB_LINKS existentes 
prompt ______________________________________________________
select 'create ' || decode(OWNER,'PUBLIC','PUBLIC','') ||
	 ' database link ' || DB_LINK || ' connect to ' || USERNAME || 
	 ' identified by xxxxxxx using ' || '''' || substr(HOST,1,30) || '''' || ';'
  from dba_db_links
 order by owner, db_link;

spool off

spool &log_path.&log_file._sinonimos_errados.txt
prompt ______________________________________________________
prompt    SINONIMOS que referem objectos inexistentes  
prompt ______________________________________________________
break on OWNER;

select a.owner, a.synonym_name, a.table_owner, a.table_name
from dba_synonyms a
where a.table_name not in 
(select object_name 
from dba_objects 
where owner=a.table_owner and object_name=a.table_name)
order by a.owner, a.synonym_name;

spool off

spool &log_path.&log_file._tamanho_objectos.txt

prompt ______________________________________________________
prompt Para VER objectos com TAMANHO > 64Kb por owner - NOVO
prompt ______________________________________________________
break on OWNER;
select substr(owner,1,15) OWNER, substr(segment_name,1,30) OBJECTO,
       segment_type, trunc(bytes/1024) Tamanho_Kb
from dba_segments
where trunc(bytes/1024) > 64
order by owner, bytes desc, segment_type, segment_name;

prompt ______________________________________________________
prompt Para VER MAIORES objectos com TAMANHO > 1000Kb - NOVO
prompt ______________________________________________________
break on OWNER;

select substr(owner,1,15) OWNER, substr(segment_name,1,30) OBJECTO,
       segment_type, trunc(bytes/1024) Tamanho_Kb
from dba_segments
where trunc(bytes/1024) > 1000
order by bytes desc, owner, segment_type, segment_name;

prompt ______________________________________________________
prompt Para VER tabelas com REGISTOS > 30000 - NOVO  
prompt ______________________________________________________

select substr(owner,1,15) OWNER, substr(table_name,1,30) TABELA, num_rows
from dba_tables
where num_rows > 30000
and owner not in ('SYS','SYSTEM')
--and (owner like 'PAA%' or owner like 'PK%')
order by num_rows desc, owner, table_name;

prompt ______________________________________________________
prompt Para VER tabelas com mais que 30 COLUNAS - NOVO
prompt ______________________________________________________

select owner, table_name, count(*) Colunas
from dba_tab_columns
having count(*) > 30
group by owner, table_name
order by colunas desc;

spool off

spool &log_path.&log_file._user_fragmentacao.txt
prompt ______________________________________________________
prompt          Fragmentação dos objectos nos owners       
prompt ______________________________________________________

--prompt Este processo e demorado e como tal nao esta activado
--prompt (para ser activado, deverá ser descomentado o select respectivo)
/*
col MAX_EXTENTS format 999999999999
break on OWNER;

select  substr(owner,1,15), substr(SEGMENT_NAME, 1,30), substr(SEGMENT_TYPE,1,10), 
	  substr(TABLESPACE_NAME,1,20), EXTENTS, MAX_EXTENTS
  from  dba_segments
  where owner not in ('SYS','SYSTEM')
  order by owner, extents desc;
*/

prompt ______________________________________________________
prompt    Fragmentação dos objectos com RELACAO < 10 - NOVO      
prompt ______________________________________________________

col MAX_EXTENTS format 999999999999
break on OWNER;

select  substr(owner,1,15), substr(SEGMENT_NAME, 1,30), substr(SEGMENT_TYPE,1,10),
        substr(TABLESPACE_NAME,1,20), EXTENTS, MAX_EXTENTS, trunc(MAX_EXTENTS/extents) "RELACAO"
from  dba_segments
where owner not in ('SYS','SYSTEM')
and trunc(MAX_EXTENTS/extents) < 10
order by (MAX_EXTENTS/extents) asc;

spool off

spool &log_path.&log_file._user_quotas_ts.txt
prompt ______________________________________________________
prompt          QUOTAS dos utilizadores nos tablespaces       
prompt ______________________________________________________
break on USERNAME;

select USERNAME, TABLESPACE_NAME
  from dba_ts_quotas
 order by 1,2;
spool off

spool &log_path.&log_file._user_default_ts.txt
prompt ______________________________________________________
prompt          Default tablespaces dos utilizadores       
prompt ______________________________________________________
break on USERNAME;

select USERNAME, DEFAULT_TABLESPACE, TEMPORARY_TABLESPACE
  from dba_users
 order by 1;
spool off

spool &log_path.&log_file._roles.txt
prompt ______________________________________________________
prompt       DEFAULT ROLES dos utilizadores 
prompt ______________________________________________________
select * 
  from dba_role_privs
 where GRANTEE not in ('SYS')
 order by GRANTEE, GRANTED_ROLE;
spool off

spool &log_path.&log_file._user_num_objs.txt
prompt ______________________________________________________
prompt   Para VER o número de objectos dos utilizadores  
prompt ______________________________________________________
break on OWNER;

select owner, object_type, count(*)
  from dba_objects
 where owner not in ('SYS')
 group by owner, object_type
 order by owner, object_type;

prompt ______________________________________________________
prompt   Para VER o número de constraints dos utilizadores  
prompt ______________________________________________________
break on OWNER;

select owner, constraint_type, status, count(*)
  from dba_constraints
 where owner not in ('SYS')
 group by owner, constraint_type, status
 order by owner, status desc, constraint_type;

prompt ______________________________________________________
prompt Para VER o estado e numero dos triggers dos utilizadores  
prompt ______________________________________________________
break on OWNER;

select owner, status, count(*)
from dba_triggers
group by owner, status;

spool off

spool &log_path.&log_file._objs_invalidos.txt

prompt ______________________________________________________
prompt     Número de OBJECTOS INVALIDOS dos utilizadores  
prompt ______________________________________________________
select owner, count(*)
  from dba_objects
 where owner not in ('SYS')
   and status='INVALID'
 group by owner
 order by owner;

prompt ______________________________________________________
prompt     Para VER os OBJECTOS INVALIDOS dos utilizadores  
prompt ______________________________________________________
PROMPT Compile todos os esquemas da base... (ENTER para continuar)
PAUSE;
break on OWNER;

select owner, object_type, object_name
from dba_objects
where owner not in ('SYS')
  and status='INVALID'
order by owner, object_type,object_name;
spool off

spool &log_path.&log_file._inits.txt

prompt ______________________________________________________
prompt                  DATA FILES
prompt ______________________________________________________
select TABLESPACE_NAME, substr(FILE_NAME,1,40) datafile
 from dba_data_files 
 order by 1,2;

prompt ______________________________________________________
prompt                  LOG FILES
prompt ______________________________________________________
select * 
from v$log;

select GROUP#, STATUS, substr(MEMBER, 1, 60) MEMBER 
  from v$logfile
order by 1;

prompt ______________________________________________________
prompt                  CONTROL FILES
prompt ______________________________________________________
select substr(NAME, 1, 60) NAME, STATUS 
  from v$controlfile
order by 1;

prompt ______________________________________________________
prompt       PARAMETROS DE LINGUAGEM
prompt ______________________________________________________
select substr(parameter,1,30) PARAMETRO, substr(value,1,20) VALOR 
  from v$nls_parameters
 order by 1,2;

prompt ______________________________________________________
prompt       PARAMETROS DA BASE DE DADOS
prompt ______________________________________________________
select substr(name,1,40) NOME, substr(value,1,100) VALOR 
  from v$parameter
 order by name,value;

spool off
