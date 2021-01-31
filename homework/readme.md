monitor.sh脚本已经给出了很详细的注释说明，不再赘述；

writercpu.sh脚本
命令详解
CPU分析—jstack
jstack：Java提供的命令。可以查看某个进程的当前线程栈运行情况。根据这个命令的输出可以定位某个进程的所有线程的当前运行状态、运行代码，以及是否死锁等等。
过程如下：

ps -mp pid -o THREAD,tid,time #这条命令可以找到耗用最高的线程和占用CPU的时间
printf "%x\n" tid  #将线程的TID转换成十六进制
jstack PID | grep TID -A100  #打印线程的堆栈信息

内存分析–jmap

jmap -heap pid   #查看jvm的内存情况
jmap -histo:livepid  #第一列，序号，无实际意义第二列，对象实例数量第三列，对象实例占用总内存数，单位：字节第四列，对象实例名称最后一行，总实例数量与总内存占用数

分析过程
1.先用jstack命令分析CPU高的原因：
发现是内存的GC造成的。

2.再用jmap –heap pid查看jvm的内存情况：
发现新生代和老年代的已使用内存都超过90%，所以会一直GC导致CPU使用率居高不下。

3.用jmap-histo:livepid查看具体的占用内存的类，截图给研发。

4.写脚本监控CPU使用率并记录类的内存使用情况
vim monitmemory.sh

#!/bin/bash
pid=`ps aux | grep tomcat | grep -v 'grep' | awk '{print $2}'`  #获取进程pid
dt=`date +"%y-%m-%d %H:%M:%S"`   #获取时间
threshold=100  #设置阀值
t=1
while (( "$t < 3" ))
do
    cpu_use=`top -b -n 1 -p $pid | grep edsuser | awk '{print $9}'`
    sleep 2
    echo $dt-$pid-$cpu_use >> /home/monitmemory/cpu.txt
    if [ $(echo "$cpu_use >= $threshold"|bc) = 1 ]; then
        /usr/local/jdk1.8/bin/jmap -histo:live $pid > /home/monitmemory/mem_$(date +%y-%m-%d-%H:%M:%S).log
    fi
    let "t++"
done

chmod +x monitmemory.sh
再把该脚本加到定时任务中，1分钟执行1次。

[www@manage-a monitmemory]$ crontab -l
* * * * * cd /home/monitmemory/ && /bin/sh /home/monitmemory/monitmemory.sh >> /home/monitmemory/123.log 2>&1