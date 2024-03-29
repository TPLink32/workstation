package main

import (
	"io"
	"log"
	"net/http"
	"time"
)

// 定义map进行路由转发
var mux map[string] func (http.ResponseWriter, *http.Request)

func main() {
	server := http.Server{
		Addr: ":8080",
		Handler: &myHandler{},
		ReadTimeout: 5 * time.Second,
	}

	mux = make(map[string]func(http.ResponseWriter, *http.Request))
	mux["/hello"] = sayHello
	mux["/bye"] = sayBye

	err := server.ListenAndServe()
	if err != nil {
		log.Fatal(err)
	}
}

type myHandler struct{}

func (*myHandler) ServeHTTP (w http.ResponseWriter, r *http.Request) {
	// map 的妙用
	if h, ok := mux[r.URL.String()]; ok {
		h(w, r)
		return
	}
	io.WriteString(w, "URL: " + r.URL.String())
}

func sayHello(w http.ResponseWriter, r *http.Request) {
	io.WriteString(w, "Hello World, this is version 3.")
}

func sayBye(w http.ResponseWriter, r *http.Request) {
	io.WriteString(w, "Bye bye, this is version 3.")
}
