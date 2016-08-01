#!/usr/bin/env python3
# -*- coding:utf-8 -*-

# 普通检查参数的方法
class Student(object):
    def get_score(self):
        return self._score

    def set_score(self, value):
        if not isinstance(value, int):
            raise ValueError('score must be an integer')
        if value < 0 or value > 100:
            raise ValueError('score must between 0 ~ 100')
        self._score = value

s = Student()
s.set_score(90)
print(s.get_score())


# property 将方法->属性
class Student1(object):

    @property
    def score(self):
        return self._score

    # property 创建装饰器score.setter, 把一个setter方法变成属性赋值
    @score.setter
    def score(self, value):
        if not isinstance(value, int):
            raise ValueError('score must be an integer')
        if value < 0 or value > 100:
            raise ValueError('score must between 0 ~ 100')
        self._score = value

s1 = Student1()
s1.score = 90
print(s1.score)

class Student2(object):
    @property
    def birth(self):
        return self._birth

    @birth.setter
    def birth(self, value):
        self._birth = value

    @property
    def age(self):
        return 2015 - self._birth

# birth 可读写属性 age 只读属性

s2 = Student2()
s2.birth = 1990
print(s2.birth)
print(s2.age)





























