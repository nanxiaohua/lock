create database db01;
use db01;
create table score(
	id int primary key,
    name varchar(20),
    math int,
    english int,
    Chinese int
    )comment'db01库score表';                  -- 数据准备


-- 表级锁-----------------------------------------------------------------------------------------------------------------------
-- 表锁--
-- 给表加读锁(read lock)：所有客户端可读表，当前客户端写表会报错，其他客户端写表被阻塞(直到当前客户端释放读锁)
lock tables score read;                      -- 开两个客户端，在当前客户端给表加读锁
select * from score;                         -- 两客户端读表均没问题
update score set math=100 where id=2;        -- 当前客户端执行该语句报错1099，因表加了读锁不能update；其他客户端执行该update语句会处于阻塞状态，直到当前客户端把锁释放
unlock tables;                               -- 当前客户端给表解锁(释放read锁)，其他客户端执行update成功(不再被阻塞)
-- 给表加写锁(write lock)：当前客户端可读写，其他客户端读写被阻塞(直到当前客户端释放写锁)
lock tables score write;                     -- 开两个客户端，在当前客户端给表加写锁
select * from score;                         
update score set Chinese=100 where id=3;     -- 当前客户端可读可写，其他客户端读写被阻塞(直到当前客户端释放写锁)
unlock tables;                               -- 当前客户端给表解锁(释放write锁)，其他客户端读写才不再被堵塞


-- 元数据锁MDL(在访问一张表时，系统自动加上元数据锁)--
-- ubuntu界面1中先开事务A
begin;                                       
select * from score;                         -- 事务A执行select操作给表自动加了shared_read类型的MDL
commit; 
-- 再在ubuntu界面2中开事务B    
begin;      
select * from score;                                    
update score set math=88 where id=1;         -- [注意此时事务A未提交]事务B也能执行select和update语句(因事务A执行select操作给表自动加了shared_read类型的MDL，事务B执行select和update操作会给表自动加shared_read和shared_write类型的MDL，这俩类型的锁是兼容的)
commit;                                      -- 此时再提交事务A和B
-- 先在ubuntu界面1中开事务C
begin;
select * from score;
commit;
-- 再在ubuntu界面2中开事务D
alter table score add column java int;        -- [注意此时事务C未提交]事务D执行该DDL语句会被阻塞(因事务C执行select操作给表自动加了shared_read类型的MDL，事务D执行alter table操作会给表自动加exclusive类型的MDL，这俩类型的锁不兼容)，直到事务C提交(即释放shared_read类型的锁)，事务D才能成功执行alter table
-- 查看元数据锁
select object_type,object_schema,object_name,lock_type,lock_duration from performance_schema.metadata_locks;         -- 进行事务A和B、事务C和D时可以将该sql语句插在事务中查看元数据锁的类型(lock_type)


-- 意向锁--------------------------------------------------------------------------------------------------
-- Ubuntu界面1开事务E
begin;
select * from score where id=1 lock in share mode;                                                               -- 该sql语句select...lock in share mode，自动给记录添加行锁的同时给表添加意向共享锁(IS)
-- Ubuntu界面2
select object_schema,object_name,index_name,lock_type,lock_mode,lock_data from performance_schema.data_locks;    -- 查看意向锁及行锁的加锁情况（可看到lock_mode有IS)
lock tables score read;                                                                                          -- 成功给表加表锁read【因意向共享锁(IS)与表锁read兼容】
unlock tables;
lock tables score write;                                                                                         -- 给表加表锁write被阻塞【因意向共享锁(IS)与表锁write互斥】直到事务A提交，加表锁write才成功
-- Ubuntu界面1提交事务E
commit;                                                                                                          
-- Ubuntu界面2释放表锁write
unlock tables;

-- Ubuntu界面1开事务F
begin;
update score set math=66 where id=1;                                                                             -- insert、update、delete、select...for update这些sql语句，自动给表加行锁的同时给表加意向排他锁(IX)
-- Ubuntu界面2
select object_schema,object_name,index_name,lock_type,lock_mode,lock_data from performance_schema.data_locks;    -- 查看意向锁及行锁的加锁情况（可看到lock_mode有IX)
lock tables score read;                                                                                          -- 给表加表锁read被阻塞【因意向排他锁(IX)与表锁read互斥】直到事务B提交，加表锁read才成功
-- Ubuntu界面1提交事务F
commit;
-- Ubuntu界面2释放表锁write
unlock tables;


-- 行级锁------------------------------------------------------------------------------------------------------------------------------------------------------------------------
use db01;
create table stu(
    id int primary key,
    name varchar(20),
	age int);
insert into stu values(1,'Tom',1),(3,'cat',3),(8,'rose',8),(11,'jetty',11),(19,'lily',19),(25,'luci',25);              -- 数据准备


-- Ubuntu界面1先开事务A
begin;
select * from stu where id=1;                                                                                          -- 执行正常的select语句，不会加任何锁
-- Ubuntu界面2再开事务B
begin;
select object_schema,object_name,index_name,lock_type,lock_mode,lock_data from performance_schema.data_locks;           -- 查看意向锁及行锁的情况，显示empty无任何锁    
-- 事务A
select * from stu where id=1 lock in share mode;                                                                        -- 执行select...lock in share mode语句，会自动对该条记录记录加S(行锁的共享锁)
-- 事务B
select object_schema,object_name,index_name,lock_type,lock_mode,lock_data from performance_schema.data_locks;           -- 再查看意向锁及行锁的情况，能看到对行记录加了S(行锁的共享锁)【当然注意到：同时也给表加了IS(表级锁的意向共享锁)】   
select * from stu where id=1 lock in share mode;                                                                        -- 事务B也给该记录加S。事务A先给该记录加了S，S和S是兼容的，所以事务B成功执行该语句
select object_schema,object_name,index_name,lock_type,lock_mode,lock_data from performance_schema.data_locks;           -- 再查看意向锁及行锁的情况，能看到对行记录加了两个S(行锁的共享锁)【当然，该表也被加了两个IS】
commit;
-- Ubuntu界面2再开事务C
begin;
select object_schema,object_name,index_name,lock_type,lock_mode,lock_data from performance_schema.data_locks;            -- 事务B已提交，此时事务B中加的锁已经释放掉了，所以此时意向锁和行锁的情况只有还未提交的事务A中的S和IS
update stu set name='Java' where id=3;                                                                                   -- 执行update语句会自动给id=3的记录加X(行锁的排他锁)
update stu set name='Java' where id=1;                                                                                   -- 执行update语句会自动给id=1的记录加X，但事务A中该记录先被加S，S和X不兼容，所以执行该update语句被阻塞
-- 事务A
commit;                                                                                                                  -- 提交事务A，事务A中的锁被释放                      
-- 事务C
commit;                                                                                                                  -- 提交事务C，事务C中的锁被释放

select object_schema,object_name,index_name,lock_type,lock_mode,lock_data from performance_schema.data_locks;             -- 检验是否没有任何锁

-- Ubuntu界面1开事务D
begin;
update stu set name='Java' where id=1;                                                                                    -- 执行update语句，innodb会自动给该记录加X(行锁的排他锁)
-- Ubuntu界面2开事务E
begin;
update stu set name='Java' where id=1;                                                                                    -- 事务D中已给该记录加了X，此时再加X会被阻塞，X和X不兼容
-- 事务D
commit;                                                                                                                   -- 事务D的锁被释放，事务E的update不再被阻塞
-- 事务E
commit;                                                                                                                   

select * from stu;
-- Ubuntu界面1先开F
begin;
update stu set name='Lei' where name='lily';                                                                              -- name字段无索引，所以执行该update语句，会将该记录的X锁升级为表锁【注：innodb的行锁是针对索引加的锁，又因name字段没索引，innodb将对表中所有记录加锁，也就是升级为表锁】          
-- 再在Ubuntu界面2开事务G
begin;
update stu set name='PHP' where id=3;                                                                                     -- 事务F给表加了表锁，所以此时update被阻塞
-- 事务F
commit;                                                                                                                   -- 事务F的表锁解除，事务G的update才执行成功
-- 事务G
commit;

select * from stu;
create index idx_stu_name on stu(name);                                                                                                                                                                
-- Ubuntu界面1先开事务H
begin;
update stu set name='lily' where name='Lei';                                                                              -- name字段有索引，update语句会自动给该记录加X锁(不会升级为表锁了)
-- Ubuntu界面2再开事务I
begin;
update stu set name='PHP' where id=3;                                                                                     -- 成功给id=3的记录加X，因事务H仅对name=Lei(id=19)的记录加X
commit;
-- 事务I
commit;


-- 间隙锁&临键锁------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
select * from stu;
-- 在Ubuntu界面1先开事务A
begin;
update stu set age=10 where id=5;                                                    -- 【索引上的等值查询(唯一索引)，给不存在的记录加锁时优化为间隙锁】给不存在的id=5记录加X锁，优化为id在3和8区域间(不含3和8)的间隙锁
-- 在Ubuntu界面2开事务B
select object_schema,object_name,index_name,lock_type,lock_mode,lock_data from performance_schema.data_locks;    -- 看到对id=8的record加了X,GAP(即对id=8前临的id=3的间隙加间隙锁，注意间隙区域不含3和8)【当然还注意到，对表也加有IX(意向排他锁)】
begin;
insert into stu values(7,'Ruby',7);                                                  -- id在3和8之间有间隙锁，插入id=7的操作被阻塞
-- 事务A
commit;                                                                              -- 释放间隙锁，事务B插入id=7才成功
-- 事务B
commit;


-- 在Ubuntu界面1
create index idx_stu_age on stu(age);                                                -- 给age字段建普通索引(非唯一索引)
begin;
select * from stu where age=3 lock in share mode;                                    -- 【索引上的等值查询(普通索引)，向右遍历时最后一个值不满足查询需求时，next_key lock退化为间隙锁】
-- 在Ubuntu界面2
select object_schema,object_name,index_name,lock_type,lock_mode,lock_data from performance_schema.data_locks;     -- 看行级锁(lock_type为record)：lock_mode为S代表临键锁，lock_data为3,3代表锁住age=3之前的间隙和age=3的记录；lock_mode为S,REC_NOT_GAP代表行锁，lock_data为3代表锁住age=3的记录；lock_mode为S,GAP代表间隙锁，lock_data为7,7代表锁住agt=7之前的间隙
-- Ubuntu界面1
commit;
-- Ubuntu界面2
commit;

-- 在Ubuntu界面1
begin;
select * from stu where id>=19 lock in share mode;                                   -- 【索引上的范围查询(唯一索引)——会访问到不满足条件的第一个值为止】输出有id=19和id=25的两条记录
-- 在Ubuntu界面2
select object_schema,object_name,index_name,lock_type,lock_mode,lock_data from performance_schema.data_locks;     -- 看行级锁：lock_mode为S,REC_NOT_GAP代表行锁，lock_data为19代表锁住id=19的记录；lock_mode为S代表临键锁，lock_data为25代表锁住id=25之前的间隙和id=25的记录；lock_mode为S，lock_data为supremum pseudo_record代表给id=25之后的id正无穷大的记录也加了临键锁
-- 在Ubuntu界面1
commit;















































