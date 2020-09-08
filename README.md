
linbrenms centos7 apache 自動化安裝
======================
### 系統：
Centos7.x

### 套件內容：
PHP 7.3 + MYSQL 5.7 + APACHE

### 使用說明：
使用前，請先至sh裡修改sql密碼

### 安裝步驟：
Step 1:
```
git clone git@10.249.33.237:po-hsiang/librnms_centos7_apach_auto_sh.git
```
Step 2:
```
sh librenms_centos7_apach_auto.sh
```
Step 3:
```
開啟瀏覽器連至：http://你的IP/install/checks

根據內容進行相關設定(如DB Password、DB Name)。
```
Step 4:
```
按照頁面提示，修改.env檔案
```
Step 5 :
```
回到centos 複製一份 conf.php 並編輯相關設定：
```
```
cp /opt/librenms/config.php.default  /opt/librenms/config.php
```
Step 6:
```
chown librenms:librenms /opt/librenms/config.php
```
Step 7:
```
操作若遇到問題，切換成root，可利用此指令除錯
```
```
cd /opt/librenms
./validate.php
```
