package main

import (
	"mysql/models"
	_ "mysql/routers"
	"github.com/astaxie/beego"
	"github.com/astaxie/beego/orm"
	_"github.com/mattn/go-sqlite3"
)

func init() {
	models.RegisterDB()
}


func main() {
	orm.Debug = true
	orm.RunSyncdb("default", false, true)
	beego.Run()
}
