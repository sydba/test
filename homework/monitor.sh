#!/bin/sh
# 获取tomcat进程ID（其中[grep -w 'tomcat']代码中的tomcat需要替换为你的tomcat文件夹名）
TomcatID=$(ps -ef |grep tomcat |grep -w 'apache-tomcat-8.5.16'|grep -v 'grep'|awk 'NR==1{print $2}')
# 获得tomcat进程数，根据自己实际情况进行修改，比如端口和tomcat名称
TomcatCount=`ps -ef |grep tomcat |grep -w 'apache-tomcat-8.5.16'|grep -v 'grep'|wc -l`

# tomcat启动程序(这里注意tomcat实际安装的路径)
StartTomcat=/home/apache-tomcat-8.5.16/bin/startup.sh
TomcatCache=/home/apache-tomcat-8.5.16/work

#定义要监控的页面地址
WebUrl=http://172.17.2.125:8080/webroot/decision

#日志输出
GetPageInfo=/home/apache-tomcat-8.5.16/TomcatMonitor.Info
TomcatMonitorLog=/home/apache-tomcat-8.5.16/TomcatMonitor.log

Monitor()
{
    echo "[info]开始监控tomcat...[$(date +'%F %H:%M:%S')]"
    if [ $TomcatCount -ge 3 ];then #这里判断Tomcat进程是否存在
        echo "[info]当前tomcat进程ID为:$TomcatID,当前进程数为:$TomcatCount,继续检测页面..."
        # 检测是否启动成功(成功的话页面会返回状态"200")
        TomcatServiceCode=$(curl -s -o $GetPageInfo -m 10 --connect-timeout 10 $WebUrl -w %{http_code})
        if [ $TomcatServiceCode -eq 302 ];then
            echo "[info]页面返回码为$TomcatServiceCode，tomcat正常，测试页面正常"
        else
            echo "[error]tomcat页面出错，请注意...状态码为$TomcatServiceCode，错误日志已输出到$GetPageInfo"
            echo "[error]页面访问出错，开始重启tomcat"
            kill -9 $TomcatID # 杀掉原tomcat进程
            sleep 3
            rm -rf $TomcatCache # 清理tomcat缓存
            $StartTomcat
        fi
    else
        echo "[error]tomcat进程不存在!tomcat开始自动重启..."
        echo "[info]$StartTomcat，请稍候..."
        rm -rf $TomcatCache
        $StartTomcat
    fi
    echo "--------------------------"
}
Monitor>>$TomcatMonitorLog

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