### Official Site  
https://www.tmp.link  
https://github.com/tmplink/tmplink_uploader

### Installation on NCI  
1. Download:  
```  
   git clone https://github.com/tmplink/tmplink_uploader.git 
   cd tmplink_uploader 
```
2. Build file myinstall.sh. The **my_path** below refers to the installation directory you specify. (Replace it with the actual directory, for example ~/soft/) :
```
   sed 's#/usr/local/bin#my_path#g' install-linux.sh > myinstall.sh
   chmod +x myinstall.sh
```
3. Installation:
```
   ./myinstall.sh
   source ~/.bashrc
```
### Useage
1. GUI version: 
```
   tmplink
```
2. Command version:
```
   tmplink-cli -file  yourfile
```   