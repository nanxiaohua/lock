create [unique|fulltext] index index_name on table_name(index_col_name,...);                -- 创建索引，[]里省略表示常规索引 
show index from table_name;                                                                 -- 查看索引，也可在后面加\G，使结果更visible
drop index index_name on table_name;                                                        -- 删除索引

-- Ubuntu server中执行
[Ubuntu@server]$ sudo mysql -u root -p 
nanzhaoru@localhost:~$ sudo mysql -u root -p                                                -- 这里输入Ubuntu用户nanzhaoru主机的密码(也称sudo密码)，输完之后显示enter password才是输入MySQL的root用户密码 【系统会缓存sudo密码15min，这段时间内不会让你再次输sudo密码】
create index idx_user_name on wz_user(name);                                                -- 表wz_user的name字段值可能重复，为该字段添加索引
create index idx_user_phone on wz_user(phone);                                              -- phone字段值，非空且唯一，为该字段创建唯一索引
create index idx_user_pro_age_sta on wz_user(profession,age,status);                        -- 为profession、age、status创建联合索引
create index idx_user_email on wz_user(email);                                              -- 为email建立索引(提升查询效率
show index from wz_user;
drop index idx_user_email on wz_user;                                                       -- 删除email的索引
 

-- SQL性能分析-------------------------------------------------------------------------------------------------------------------------
show global status like 'Com_______'                                                        -- 通过该sql指令，可以查看当前数据库insert、update、delete、select的访问频次，从而决定主要优化增删改查的哪个部分(哪个频次高就优化哪个)


-- 慢查询日志--
show variables like 'slow_query_log';                                                       -- MySQL的慢查询日志默认off【需要在MySQL的配置文件中配置/编辑信息：slow_query_log=1(开启MySQL慢查询日志开关)、long_query_time=2(设置慢日志的时间为2秒，sql语句执行时长超2s就会被视为慢查询，记录在慢查询日志里)】
show variables like 'slow_query_log_file';                                                  -- (WSL即Linux环境下)Ubuntu界面连接MySQL执行该sql，查询到MySQL慢查询日志文件的存储路径：/var/lib/mysql/localhost-slow.log
-- Ubuntu界面执行
nanzhaoru@localhost:~$ sudo vi /etc/mysql/mysql.conf.d/mysqld.cnf                           -- 用vi编辑器对该目录的内容编辑【注：MySQL配置文件在wsl环境Ubuntu中的典型路径：/etc/mysql/mysql.conf.d/mysqld.cnf】
slow_query_log=1 
long_query_time=2                                                                           -- 在[mysql]段末添加/修改参数：按G或控制下箭头移光标到段末，按i进入vi编辑器的insert编辑模式，[mysql]段末输入这两个参数，完成后按esc退出编辑模式(左下角insert消失代表已退出编辑模式)，输入wq按enter键保存编辑并退出vi【vi编辑器的快捷键：按i代表进入编辑模式；按esc代表退出编辑模式；输入wq后按enter代表保存并退出；输入q!后按enter代表不保存并退出】
nanzhaoru@localhost:~$ sudo systemctl restart mysql                                         -- 另开Ubuntu终端，重启MySQL(必须！)，验证编辑
nanzhaoru@localhost:~$ sudo mysql -u root -p                                                -- 先后输入sudo密码和MySQL密码(MySQL我没设密码)，连接MySQL
use itcast;                                                                                 -- 连接MySQL后，指定itcast数据库
show variables like 'slow_query_log';                                                       -- 此时，输出结果应为ON(即慢查询日志为开启状态)
show variables like 'long_query_time';                                                      -- 此时，输出结果应为编辑后的2.000秒
exit                                                                                        -- 退出MySQL
nanzhaoru@localhost:~$ sudo ls -l /var/lib/mysql                                            -- 使用sudo查看目录内容(能看到有localhost_slow.log且有内容)   【注：cd /var/lib/mysql，用cd查看会报错，因/var/lib/mysql目录归MySQL用户所有，普通用户包括cd用户、sudo用户无权进入此目录】
nanzhaoru@localhost:~$ sudo cat /var/lib/mysql/localhost-slow.log                           -- (以管理员权限)查看慢查询日志文件的内容
nanzhaoru@localhost:~$ sudo tail -f /var/lib/mysql/localhost-slow.log                       -- tail -f表示实时监控文件的新增内容(动态显示日志更新，追踪正在发生的慢查询)。比如select一张1000万条记录的表，耗时13s，则会在这条指令下方实时显示(可开两个Ubuntu验证)
-- 总之，最终目标是通过查看慢查询日志来定位执行效率较低(需要优化)的sql


-- profile详情--
select @@have_profiling;                                                                    -- YES表示当前MySQL支持profile操作  
set profiling=1;                                             
select @@profiling;                                                                         -- 默认profiling是关闭的(0),开启后是1
show profiles;                                                                              -- 查看每一条sql的耗时基本情况  【show profiles能够在做SQL优化时帮助我们了解时间都耗费到哪里去了】
show profile for query query_id;                                                            -- 查看指定query_id的sql语句各个阶段的耗时情况
show profile cpu for query query_id;                                                        -- 查看指定query_id的sql语句cpu的使用情况


-- explain执行计划--
select * from tb_sku where sn='100000003145001';                                            -- 后可加\G将输出的表格信息更visible，这里tb_sku使一张1000万记录的表，该sql耗时20s，因sn没有索引
select * from tb_sku where id=1\G;                                                          -- 对比上条sql语句，该sql耗时0s(因id为主键，m默认是聚集索引)
create index idx_sku_sn on tb_sku(sn);                                                      -- 对sn字段创建索引。该过程(构建B+树的数据结构)也耗时，因数据海量
show index from tb_sku;
select * from tb_sku where sn='100000003145001';                                            -- 建完索引后，再执行该sql耗时明显变少，这就是索引对查询效率的提升
explain select * from tb_sku where sn='100000003145001';                                    -- 查看该sql查询语句的执行计划
-- 最左前缀法则
explain select * from wz_user where profession='软件工程' and age=31 and status='0';         -- (执行计划的)输出结果中可看到走了pro_age_sta联合索引，索引长度为54
explain select * from wz_user where profession='软件工程' and age=31;                        -- 输出结果中可看到走了pro_age_sta联合索引，索引长度为49，说明status字段的索引长度为5
explain select * from wz_user where profession='软件工程';                                   -- 输出结果中可看到走了pro_age_sta联合索引，索引长度为47，说明age字段的索引长度为2
explain select * from wz_user where age=31 and status='0';                                  -- 输出结果中可看到type值为ALL(走的全表扫描)，因为不满足最左前缀法则(最左边的列profession必须存在)
explain select * from wz_user where status='0';                                             -- 输出结果中可看到typr值为ALL(走的全表扫描)，possible keys(可能用到的索引)和key(实际用的索引)均为NULL
explain select * from wz_user where profession='软件工程' and status='0';                    -- 输出结果中可看到走了联合索引，索引长度47，说明只有profession走了索引，status没有，即索引部分失效(因跳过age字段，后面的索引字段失效)
explain select * from wz_user where age=31 and status='0' and profession='软件工程';         -- 输出结果中可看到走了联合索引，且索引长度54，说明3个字段的索引全部都用上了。结论：sql语句字段的位置不影响索引的使用，字段的有无才决定
-- 范围查询
explain select * from wz_user where profession='软件工程' and age>30 and status='0';         -- 可看到走了联合索引，索引长度49，因age用了范围查询，那么age后面的status索引将失效
explain select * from wz_user where profession='软件工程' and age>=30 and status='0';        -- 可看到走了联合索引，索引长度54(所有字段都走了索引，即索引全生效)。结论：业务中尽量用>=或<=的运算符来规避索引失效的情况
-- 索引列运算
explain select * from wz_user where phone='17799990015';                                    -- phone字段有单列索引，输出结果中也可看到走了idx_user_phone，该索引长度为47
explain select * from wz_user where substring(phone,10,2)='15';                             -- 输出结果中possible keys和key均为NULL(即没走索引)，type为ALL(走的全表扫描)。因对phone字段做了函数运算
-- 字符串不加引号
explain select * from wz_user where phone=17799990015;                                      -- 这条select的sql语句中，phone值即使不加单引号也能查到记录，但这条查询语句的执行计划中type为ALL(走的全表扫描)，possible keys为idx_user_phone，key却为NULL，key_len也为NULL，本可能走phone的单列索引，但因未加单引号，实际并未走索引查找导致索引失效
explain select * from wz_user where profession='软件工程' and age=31 and status='0';         -- 代码规范，走索引，索引全部生效(索引长度54) 
explain select * from wz_user where profession='软件工程' and age=31 and status='0';         -- 代码不规范，索引部分生效，索引长度49可知status部分的索引失效
-- 模糊查询
explain select * from wz_user where profession like '软件%';                                -- 可知走了pro_age_sta索引，索引长度47。结论：尾部模糊匹配是走索引的 
explain select * from wz_user where profession like '%工程';                                -- 头部模糊匹配不走索引，索引全部失效，所以能看到type为ALL，possibl_keys和key、key_len均为NULL  【结论：在大数据量情况下，我们要规避前面加%的模糊查询，因这样不走索引，查询会全表扫描，性能很低】
-- or连接的条件
explain select * from wz_user where id=10 or age=23;                                       -- or前id有主键索引，or后age无索引，所以不走任何索引，而是全表扫描(type为ALL)，possible_keys为PRIMARY，但key为NULL(实际未走索引) 【用or分割开的条件，如果or前的条件中的列有索引，而or后面的列无索引，那么涉及的索引都不会被用到】
explain select * from wz_user where phone='17799990004' or age=23;                         -- or前phone有单列索引，or后age无索引，因此不走任何索引，而是全表扫描(type为ALL)，possible_keys为phone的索引，但key为NULL(实际未用到)，而是全表扫描
create index idx_user_age on wz_user(age);                                                 -- 给age字段建索引
explain select * from wz_user where id=10 or age=23;                                       -- or前后的字段都有索引，此时type为index_merge，possible_keys为PRIMARY和age的索引，实际也用到了这俩索引(两个索引都生效)
explain select * from wz_user where phone='17799990004' or age=23;                         -- 同上，or前后的字段都有索引且编码规范，两个索引都生效
-- 数据分布影响
explain select * from wz_user where phone>='17799990020';                                  -- 走phone的索引
explain select * from wz_user where phone>='17799990000';                                  -- MySQL评估器认为使用索引比全表扫描慢，所以这里显示type为ALL，key为NULL
explain select * from wz_user where phone>='17799990010';                                  -- 同上，wz_user表的大部分记录都符合>='17799990010'，MySQL认为走全表更快
explain select * from wz_user where phone>='17799990013';                                  -- wz_user表的大部分记录不满足>='17799990013'，走索引更快。输出结果可知key不为NULL，用到了phone的索引(type为range)
explain select * from wz_user where profession is not null;                                -- possible_keys(可用索引)仍为pro_age_sta的联合索引，但key为NULL(并未走索引)，type为ALL(走的全表扫描)。因为表的大部分数据都符合条件，MySQL认为全表扫描更快
update wz_user set profession=null;                                                        -- (全部改为null时记得备份原数据)是否走索引与NULL/NOT NULL无关，而是与数据分布情况有关
explain select * from wz_user where profession is null;                                    -- 此时全表大部分记录都符合条件，走全表比走索引块，所以type为ALL，key为NULL
explain select * from wz_user where profession is not null;                                -- 此时全表大部分记录不符合条件，走索引更快，所以key为idx_user_pro_age_sta，type为range
-- SQL提示
explain select * from wz_user where profession='软件工程';                                   -- 符合最左前缀法则且编码规范，走索引pro_age_sta
create index idx_user_pro on wz_user(profession);                                           -- 给profession建单列索引
explain select * from wz_user where profession='软件工程';                                   -- possible keys为idx_user_pro_age_sta,idx_user_pro，而key为idx_user_pro_age_sta(MySQL优化器自动选择了该索引)
explain select * from wz_user use index(idx_user_pro) where profession='软件工程';           -- possible keys和key为idx_user_pro，MySQL接受了建议走了该索引 
explain select * from wz_user ignore index(idx_user_pro) where profession='软件工程';        -- possible keys和key均为pro_age_sta，没用pro索引
explain select * from wz_user force index(idx_user_pro_age_sta) where profession='软件工程'; -- 强制使用pro_age_sta索引  【SQL提示是优化数据库的一个重要手段，简单来说，就是在sql语句中加入一些人为的提示来达到优化操作的目的】
-- 覆盖索引
drop index idx_user_age on wz_user;                
drop index idx_user_email on wz_user;
drop index idx_user_pro on wz_user;                                                         -- 准备工作：删掉age、email、pro的各单列索引
show index from wz_user;
explain select * from wz_user where profession='软件工程' and age=31 and status='0';                                -- extra为using index condition【查询使用索引，后需回表查询】
explain select id, profession from wz_user where profession='软件工程' and age=31 and status='0';                   -- extra为using where; using index【查询使用索引，需要的数据在索引列中能找到，无需回表查询】
explain select id, profession, age from wz_user where profession='软件工程' and age=31 and status='0';              -- extra为using where; using index【查询使用索引，需要的数据在索引列中能找到，无需回表查询】
explain select id, profession, age, status from wz_user where profession='软件工程' and age=31 and status='0';      -- extra为using where; using index【查询使用索引，需要的数据在索引列中能找到，无需回表查询】以上4个执行计划中除extra之外完全一致 【以上3个执行计划中，走的联合索引(属二级索引)，二级索引中，其叶子节点挂的就是id，所以select id字段和索引中包含的字段，不需回表查询，不需再走聚集索引】
explain select id, profession, age, status, name from wz_user where profession='软件工程' and age=31 and status='0';-- extra为using index condition【查询使用索引，后需回表查询】。因该查询语句中，select部分的name字段在该二级索引中是不含的，所以需要根据id再走聚集索引取到name字段(即回表查询) 【结论：尽量避免使用select *，因为很容易触发回表查询(除非有建所有字段的联合索引)，而一旦进行回表查询，性能就较低了】
-- 前缀索引
select count(distinct email)/count(*) from wz_user;                                         -- 前缀长度可根据索引的选择性来决定，而选择性是指不重复的索引值(基数)和表记录总数的比值，索引选择性越高则查询效率越高。唯一索引的选择性是1，这是最好的索引选择性，性能也最好
select count(distinct substring(email,1,5))/count(*) from wz_user;                          -- 截10个时，该sql的执行结果为1；截9/8/7/6/5个，输出结果为0.9583。若想索引的选择性最高→截10；若想同时平衡索引体积→选5
create index idx_email_5 on wz_user(email(5));                                              -- 对截取的email字段的前5个字符串建立索引
show index from wz_user;                                                                    -- 输出表中，idx_email_5索引的sub_part为5，其他索引为NULL(是对相关字段的整个内容索引)
explain select * from wz_user where email='daqiao666@sina.com';                             -- 走了email_5这个索引                
-- 单列索引与联合索引
explain select id, phone, name from wz_user where phone='17799990010' and name='韩信';       -- possible keys为idx_user_phone,idx_user_name(phone和name都各有单列索引，且phone的为唯一索引)，key为idx_user_phone，即实际只走了phone的索引。而select要取的不只有id和phone，还要取name，那么必然要回表查询
create index idx_user_phone_name on wz_user(phone,name);                                    -- 建phone和name的联合索引
create unique index idx_user_phone_name on wz_user(phone,name);                             -- phone已经是唯一索引了，那么phone_name的联合索引也是唯一索引，可加unique
explain select id, phone, name from wz_user where phone='17799990010' and name='韩信';      -- possible keys为idx_user_phone,idx_user_name,idx_user_phone_name，key为idx_user_phone(仍只走phone的索引，这是MySQL自己选择的结果) ，extra为NULL  【多条件联合查询时，MySQL优化器会评估哪个字段的索引效率更高，会选择该索引完成本次查询】
explain select id, phone, name from wz_user use index(idx_user_phone_name) where phone='17799990010' and name='韩信';    -- 建议MySQL用phone_name联合索引，possible keys和key均为idx_user_phone_name，extra为using index【走覆盖索引，无回表查询】，type为const(走的是唯一索引或主键索引，此处不是主键索引)





















-- SQL优化--------------------------------------------------------------------------------------------------------------------------------------------------
-- 插入数据--
nanzhaoru@localhost:~$ sudo mysql --local-infile -u root -p                                       -- Ubuntu客户端连接MySQL服务器时，加上参数--local-infile
set global local_infile=1;                                                                        -- 【准备工作：开启数据库以及建好表结构后】(设置全局参数local_infile为1)启用local_infile，开启从本地加载文件导入数据的开关
load data local infile '/mnt/d/BaiduNetdiskDownload/进阶篇/相关SQL脚本/load_user_100w_sort.sql' into table tb_user fields terminated by',' lines terminated by '\n';    -- 该路径已经通过验证能输出前10行内容，可直接拿来用
select count(*) from tb_user;                                                                     -- 验证是否有100万条
-- 附：load指令前的准备操作
nanzhaoru@localhost:~$ sudo ls -l /mnt/d/BaiduNetdiskDownload/进阶篇/相关SQL脚本                    -- 长格式罗列出这个目录下的内容，可找到列出的内容中有load_user_100w_sort.sql这个100万条模拟数据的脚本 【/mnt是Linux系统中专门用于临时挂载外部存储设备的目录，WSL自动把Windows的磁盘挂载到/mnt/下。/mnt/c/代表C盘，/mnt/d/代表D盘(注c、d要小写)】
nanzhaoru@localhost:~$ wc -l /mnt/d/BaiduNetdiskDownload/进阶篇/相关SQL脚本/load_user_100w_sort.sql  -- Linux命令wc -l表示统计文件中的行数，结果显示1000000  【wc -w表示统计单词数，wc -c表示统计字节数，wc -m统计字符数】  
nanzhaoru@localhost:~$ head /mnt/d/BaiduNetdiskDownload/进阶篇/相关SQL脚本/load_user_100w_sort.sql   -- Linux命令head默认输出文件开头前10行   【head -n 5 /mnt/... 表示自定义输出文件前5行】
nanzhaoru@localhost:~$ pwd                                                                         -- 显示当前所在的绝对路径，结果为/home/nanzhaoru

cp '/mnt/d/BaiduNetdiskDownload/进阶篇/相关SQL脚本/load_user_100w_sort.sql' ~/                       -- 【也可以不用/mnt挂载的路径，用短路径导入】将文件从Windows目录复制到Linux家目录
load data local infile '/home/nanzhaoru/load_user_100w_sort.sql' into table tb_user fields terminated by ',' lines terminated by '\n';    -- 使用短路径导入   【在使用load指令时，也需按照主键进行顺序插入，要知道顺序插入的性能高于乱序插入】 【这100万条数据若执行insert指令插入要耗时十多分钟】  
-- 主键优化【尽量降低主键长度、尽量顺序插入(主键乱序插入可能导致页分裂)、尽量避免修改主键(会动索引的数据结构，代价较大)】--
-- order by优化--
drop index idx_user_phone on wz_user;
drop index idx_user_name on wz_user;
drop index idx_user_phone_name on wz_user;
explain select id,age from wz_user order by age;                                                  -- 严格按照最左前缀法则的MySQL版本显示key为NULL，type为ALL，extra为using filesort。而我的版本不同优化器不同，我这显示extra为using index,using filesort【检索走了索引，但不是经索引排序】(possible keys为NULL，key为pro_age_sta，这是该版本的sql优化器的自动选择)
explain select id,age,phone from wz_user order by age,phone;                                      -- age和phone都无索引，key为NULL(不走索引)，type为ALL(走全表扫描)，extra为using filesort【通过表的索引或全表扫描，读取满足条件的数据行，然后在排序缓冲区sort buffer中完成排序操作，所有不是通过索引直接返回排序结果的排序都叫filesort排序】
create index idx_user_age_phone on wz_user(age,phone);                                           
explain select id,age,phone from wz_user order by age,phone;                                      -- 走索引age_phone，type为index，extra为using index【说明优化为经索引排序】  【通过有序索引扫描直接返回有序数据，这种情况为using index，不需额外排序，效率高】
explain select id,age,phone from wz_user order by age;            
explain select id,age,phone from wz_user order by age desc,phone desc;                            -- 走索引age_phone，extra为backward index scan(反向扫描索引),using index(经索引排序)
explain select id,age,phone from wz_user order by phone,age;                                      -- age_phone索引中age在前，但order by部分phone在前，不符最左前缀法则，extra为using index,using filesort
explain select id,age,phone from wz_user order by age asc,phone desc;                             -- 走索引age_phone，extra为using index,using filesort(因此时phone需额外倒序排列)   【show index的结果表中，collation为A代表asc升序】
create index idx_user_age_pho_ad on wz_user(age asc,phone desc);                                  -- 建立age升序phone降序的联合索引
explain select id,age,phone from wz_user order by age asc,phone desc;                             -- 此时，extra为using index(经索引排序)
explain select id,age,phone from wz_user order by age asc,phone asc;                              -- 不用说，因有age_phone的联合索引(默认均升序)，所以extra为using index(只经索引排序) 
-- 【结论：建了age_phone联合索引，若order by的age,phone均为升序/降序，则extra为using index(经索引排序)；若一个升序一个降序，则extra为using index,using filesort，此时可针对字段的升降序建对应的联合索引进行优化，使explain的执行结果中extra为using index】
-- group by优化--
drop index idx_user_age_sta on wz_user;                                                          -- ......删掉所有索引，仅保留主键索引
explain select profession,count(*) from wz_user group by profession;                             -- extra为using temporary【使用临时表，性能较低】
create index idx_user_pro_age_sta on wz_user(profession,age,status);    
explain select profession,count(*) from wz_user group by profession;                             -- 建完联合索引后，用到了该索引，type优化为index，extra为using index【性能较高】
explain select age,count(*) from wz_user group by age;                                           -- possible keys和key为pro_age_sta，type为index，extra为using index,using temporary【性能一般】   【这里出现using temporary是因为group by的条件不符合最左前缀法则】
explain select profession,age,count(*) from wz_user group by profession,age;                     -- possible keys和key为pro_age_sta，type为index，extra为using index(因group by的条件符合最左前缀法则，所以走索引)
explain select age,count(*) from wz_user where profession='软件工程' group by age;                -- where和group by的条件满足最左前缀法则，extra为using index
-- 【结论：①在分组操作时，可通过索引来提高效率；②分组操作时，索引的使用也是要看最左前缀法则的】
-- limit优化--
select * from tb_sku limit 0,10;                                                                 -- 返回第1(0÷10+1)页数据，每页10条记录(耗时0s)   tb_sku是一张有1000万条记录的表
select * from tb_sku limit 1000000,10;                                                           -- 返回第100001(1000000÷10+1)页数据，每页10条记录(耗时2s)
select * from tb_sku limit 9000000,10;                                                           -- 耗时20s，limit数据越大越耗时           【limit 2000000,10此时MySQL排序前2000010记录，仅返回2000000~2000010的记录，其他记录丢弃，查询排序的代价非常大】
select id from tb_sku order by id limit 9000000,10;                                              -- order by的条件为id，select只取id，耗时11s
select * from tb_sku where id in (select id from tb_sku order by id limit 9000000,10);           -- 会显示版本不支持子查询里含limit
select s.* from tb_sku s,(select id from tb_sku order by id limit 9000000,10) a where s.id=a.id; -- 耗时11s        
-- 【优化思路：一般分页查询时，通过创建覆盖索引能较好地提高性能，可通过覆盖索引加子查询形式来优化limit】
-- count优化--
explain select count(*) from tb_user;                                                            -- MyISAM引擎把一个表的总行数存在了磁盘上，因此执行count(*)时直接返回这个数，效率很高；但InnoDB引擎比较麻烦，执行count(*)时需把数据一行行从引擎里读出，然后累积计数   【count()是一个聚合函数，对于返回的结果值，一行行地判断，如果count函数的参数不是NULL，累计值就加1，否则不加。最后返回累计值】
select count(id) from tb_user;                                                                   -- count(id)：InnoDB引擎会遍历整个表，把每一行的主键id都取出来，返回给服务层。服务层拿到主键后，直接按行进行累加(主键不可能为NULL)
select count(profession) from tb_user;                                                           -- count(字段)：没有not null约束时，InnoDB引擎会遍历整张表把每一行的字段值都取出，返回给服务层，服务层判断是否为null，否则计数累加；有not null约束时，InnoDB引擎会遍历整张表把每一行的字段取出，返回给服务层，直接按行进行累加
select count(*) from tb_user;                                                                    -- count(*)：InnoDB引擎并不会把全部字段取出，而是专门做了优化，不取值，服务层直接按行进行累加
select count(1) from tb_user;                                                                    -- InnoDB引擎遍历整张表，但不取值。服务层对于返回的每一行，放一个数字“1”进去，直接按行进行累加。这里count(0)、count(-1)都可      
-- 【结论：按效率排序：count(字段)<count(主键id)<count(1)≈count(*)，尽量用count(*)。因count(字段)需判断是否null然后累计，count(主键id)直接累计，毕竟id不为null】
-- update优化--
事务A
begin;
update course set name='JavaEE' where id=1;                                                      -- 事务A中，根据id字段进行更新，因id有(主键)索引，该更新只涉及行级锁
事务B
begin;
update course set name='kafka' where id=4;                                                       -- 事务A未commit，事务B也能update成功
事务A
commit;
事务B
commit;

事务C
begin;
update course set name='SpringBoot' where name='PHP';                                            -- 根据name字段更新，因name字段无索引，该更新涉及表锁
事务D
begin;
update course set name='kafka2' where id=4;                                                      -- 事务C中触发了表锁，因此该更新语句执行失败
事务C
commit;                                                                                          -- 事务C提交后，表锁取消，此时事务D的update才会成功
事务D
commit;                                                                          

create index idx_course_name on course(name);                                                    -- 给name字段建索引
事务E
begin;
update course set name='Spring' where name='Springboot';                                         -- 根据name字段更新，因name有索引，该update语句涉及行级锁
事务F 
begin;
update course set name='cloud' where id=4;                                                        -- 事务F中，该update语句执行成功
事务E
commit;
事务F
commit;
-- 【结论：在执行update语句时，要根据索引字段进行更新，否则会出现行锁升级为表锁的问题】    InnoDB的行锁是针对索引加的锁(而不是针对记录加的锁)，并且该索引不能失效，否则会从行级锁升级为表锁(并发性能就会降低)



