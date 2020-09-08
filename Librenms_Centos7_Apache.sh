#Centos 7 + Apache + MySQL(5.7) install Librenms

#取得 ip
ip=`ip addr | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1'`

#安裝相關套件
sudo yum install epel-release -y
rpm -Uvh https://mirror.webtatic.com/yum/el7/webtatic-release.rpm
sudo yum install -y git cronie fping jwhois ImageMagick mtr MySQL-python net-snmp net-snmp-utils nmap python-memcached rrdtool policycoreutils-python httpd unzip python3 python3-pip

#安裝php7.3
sudo yum localinstall http://rpms.remirepo.net/enterprise/remi-release-7.rpm -y
sudo yum -y install yum-utils
sudo yum-config-manager --enable remi-php73
sudo yum -y install mod_php php-cli php-common php-curl php-gd php-mbstring php-process php-snmp php-xml php-zip php-memcached php-mysqlnd

#新增使用者
sudo useradd librenms -d /opt/librenms -M -r
sudo usermod -a -G librenms apache

#下載LibreNMS
cd /opt
sudo git clone https://github.com/librenms/librenms.git librenms
sudo chown librenms:librenms -R /opt/librenms
#設定 librenms
sudo chmod 770 /opt/librenms
sudo setfacl -d -m g::rwx /opt/librenms/rrd /opt/librenms/logs /opt/librenms/bootstrap/cache/ /opt/librenms/storage/ /opt/librenms/cache
sudo setfacl -R -m g::rwx /opt/librenms/rrd /opt/librenms/logs /opt/librenms/bootstrap/cache/ /opt/librenms/storage/ /opt/librenms/cache

#安裝PHP依賴項
su - librenms <<EOF
    ./scripts/composer_wrapper.php install --no-dev
    exit
EOF

#設定資料庫(這邊注意要修改密碼，請在這裡先填入密碼在使用)
sudo systemctl enable mysqld

mysql -u root -p你的密碼 <<EOF
	CREATE DATABASE librenms CHARACTER SET utf8 COLLATE utf8_unicode_ci;
	CREATE USER 'librenms'@'localhost' IDENTIFIED BY '你的密碼';
	GRANT ALL PRIVILEGES ON librenms.* TO 'librenms'@'localhost';
	FLUSH PRIVILEGES;
	exit
EOF

#在/etc/my.cnf 後面加入這兩行
echo innodb_file_per_table=1  >>/etc/my.cnf
echo  lower_case_table_names=0 >>/etc/my.cnf
# 重啟MYSQL
sudo systemctl restart mysqld

#設定Web Server
echo date.timezone = \"Asia/Taipei\" >> /etc/php.ini
echo php\_admim\_value[open_basedir] \= \"\/opt\/librenms\:\/usr\/lib64\/nagios\/plugins\:\/dev\/urandom\:\/usr\/sbin\/fping\:\/usr\/sbin\/fping6\:\/usr\/bin\/snmpgetnext\:\/usr\/bin\/rrdtool\:\/usr\/bin\/snmpwalk\:\/usr\/bin\/snmpget\:\/usr\/bin\/snmpbulkwalk\:\/usr\/bin\/snmptranslate\:\/usr\/bin\/traceroute\:\/usr\/bin\/whois\:\/bin\/ping\:\/usr\/sbin\/mtr\:\/usr\/bin\/nmap\:\/usr\/sbin\/ipmitool\:\/usr\/bin\/virsh\:\/usr\/bin\/nfdump\" >> /etc/php.ini

#設定Apache
echo		\<VirtualHost \*:80\>	 >> /etc/httpd/conf.d/librenms.conf
echo		   DocumentRoot \/opt\/librenms\/html\/	 >> /etc/httpd/conf.d/librenms.conf
echo		 ServerName $ip 	 >> /etc/httpd/conf.d/librenms.conf
echo		 	 >> /etc/httpd/conf.d/librenms.conf
echo			AllowEncodedSlashes NoDecode >> /etc/httpd/conf.d/librenms.conf
echo		 \<Directory \"\/opt\/librenms\/html\/\"\>	 >> /etc/httpd/conf.d/librenms.conf
echo		 	Require all granted >> /etc/httpd/conf.d/librenms.conf
echo		 AllowOverride All	 >> /etc/httpd/conf.d/librenms.conf
echo		  Options FollowSymLinks MultiViews	 >> /etc/httpd/conf.d/librenms.conf
echo		  \<\/Directory\>	 >> /etc/httpd/conf.d/librenms.conf
echo		 \<\/VirtualHost\>	 >> /etc/httpd/conf.d/librenms.conf
sudo systemctl enable --now httpd
sudo systemctl restart httpd


#設定SELinux
sudo yum install -y policycoreutils-python
sudo semanage fcontext -a -t httpd_sys_content_t '/opt/librenms/logs(/.*)?'
sudo semanage fcontext -a -t httpd_sys_rw_content_t '/opt/librenms/logs(/.*)?'
sudo restorecon -RFvv /opt/librenms/logs/
sudo semanage fcontext -a -t httpd_sys_content_t '/opt/librenms/rrd(/.*)?'
sudo semanage fcontext -a -t httpd_sys_rw_content_t '/opt/librenms/rrd(/.*)?'
sudo restorecon -RFvv /opt/librenms/rrd/
sudo semanage fcontext -a -t httpd_sys_content_t '/opt/librenms/storage(/.*)?'
sudo semanage fcontext -a -t httpd_sys_rw_content_t '/opt/librenms/storage(/.*)?'
sudo restorecon -RFvv /opt/librenms/storage/
sudo semanage fcontext -a -t httpd_sys_content_t '/opt/librenms/bootstrap/cache(/.*)?'
sudo semanage fcontext -a -t httpd_sys_rw_content_t '/opt/librenms/bootstrap/cache(/.*)?'
sudo restorecon -RFvv /opt/librenms/bootstrap/cache/
sudo setsebool -P httpd_can_sendmail=1

#建立http_fping.tt
echo	module http_fping 1.0\;	 >> /opt/http_fping.tt
echo		 >> /opt/http_fping.tt
echo	require {	 >> /opt/http_fping.tt
echo	type httpd_t\;	 >> /opt/http_fping.tt
echo	class capability net_raw\;	 >> /opt/http_fping.tt
echo	class rawip_socket { getopt create setopt write read }\;	 >> /opt/http_fping.tt
echo	}	 >> /opt/http_fping.tt
echo		 >> /opt/http_fping.tt
echo	#============= httpd_t ==============	 >> /opt/http_fping.tt
echo	allow httpd_t self:capability net_raw\;	 >> /opt/http_fping.tt
echo	allow httpd_t self:rawip_socket { getopt create setopt write read }\;	 >> /opt/http_fping.tt

cd /opt
sudo checkmodule -M -m -o http_fping.mod http_fping.tt
sudo semodule_package -o http_fping.pp -m http_fping.mod
sudo semodule -i http_fping.pp

#設定防火牆
sudo firewall-cmd --zone public --add-service http
sudo firewall-cmd --permanent --zone public --add-service http
sudo firewall-cmd --zone public --add-service https
sudo firewall-cmd --permanent --zone public --add-service https

#配置snmpd
sudo cp /opt/librenms/snmpd.conf.example /etc/snmp/snmpd.conf
#將snmp.conf檔案裏面的字串修改成自己要的
sudo sed -i -e 's/RANDOMSTRINGGOESHERE/public/g' /etc/snmp/snmpd.conf

sudo curl -o /usr/bin/distro https://raw.githubusercontent.com/librenms/librenms-agent/master/snmp/distro
sudo chmod +x /usr/bin/distro
sudo systemctl enable snmpd
sudo systemctl restart snmpd

#加入排程
sudo cp /opt/librenms/librenms.nonroot.cron /etc/cron.d/librenms
#轉出 logs 目錄下的記錄檔
sudo cp /opt/librenms/misc/librenms.logrotate /etc/logrotate.d/librenms

#設定權限
sudo chown -R librenms:librenms /opt/librenms
sudo setfacl -d -m g::rwx /opt/librenms/rrd /opt/librenms/logs /opt/librenms/bootstrap/cache/ /opt/librenms/storage/
sudo chmod -R ug=rwX /opt/librenms/rrd /opt/librenms/logs /opt/librenms/bootstrap/cache/ /opt/librenms/storage/

#clear
echo "安裝完成"
echo "請開啟網址: http://"$ip"/install/checks 請開啟網頁繼續其它設定"
