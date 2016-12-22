## 安装说明


### marathon-lb
marathon-lb目录放置的是marathon-lb的镜像文件,使用以下命令导入到docker

```
docker load<marathon-lb.tar.gz
```


### open-falcon
open-falcon 是已经全部编译好的组件打包, 默认编译好的路径是"/dcos/open-falcon"
如果你部署的非默认路径,唯一特别注意的是以下组件目录路径需要改动

**目录路径**
```
----dashboard
#修改此组件env/bin 目录下所有 gunicorn* python文件,将python环境引用路径进行修改
my_path="自定义路径"
sed -i "s/dcos\/open-falcon\//\/${my_path}\//" $(ls | grep gunicorn)

#修改组件 rrd 目录下的config.py ,配置BASE_DIR 变量
BASE_DIR = "/dcos/open-falcon/dashboard/"

---graph
#修改配置文件cfg.json 中rrd数据目录路径
	"rrd": {
		"storage": "/dcos/open-falcon/dashboard/rrd/data/6070"
	},
```

**配置修改**
其他配置修改可参照:http://book.open-falcon.org/zh/quick_install/graph_components.html 说明
或参照附件中的open-falcon部署配置文档

如果你想自己配置的可到http://book.open-falcon.org/zh/quick_install/index.html下载部署

### registry_hub
registry 采用vmware 的harbor 构建


