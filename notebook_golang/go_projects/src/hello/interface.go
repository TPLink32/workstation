package main

import (
	"fmt"
	"math"
)

// 关于几何体的基本接口
type geometry interface {
	area() float64
	perim() float64
}

type rect struct {
	width, height float64
}

type circle struct {
	radius float64
}

// 实现接口中的方法
// area方法接收rect类型的值
func (r rect) area() float64 {
	return r.width * r.height
}

func (r rect) perim() float64 {
	return 2 * (r.width + r.height)
}

func (c circle) area() float64 {
	return 2 * math.Pi * c.radius
}

func (c circle) perim() float64 {
	return 2 * math.Pi * c.radius
}

// measure函数, 调用被命名接口中的方法
func measure(g geometry) {
	 fmt.Println(g)
	 fmt.Println(g.area())
	 fmt.Println(g.perim())
}

func main() {
	r := rect{width: 3, height: 4}
	c := circle{radius: 5}

	measure(r)
	measure(c)
}















