#include "Module.h"

static struct StudentTag
{
	char *strName; // ѧ������
	char *strNum; // ѧ��
	int iSex; // ѧ���Ա�
	int iAge; // ѧ������
};

static int Student(lua_State *L)
{
	size_t iBytes = sizeof(struct StudentTag);
	struct StudentTag *pStudent;
	pStudent = (struct StudentTag *)lua_newuserdata(L, iBytes);

	return 1; // �µ�userdata�Ѿ���ջ����
}

static int GetName(lua_State *L)
{
	struct StudentTag *pStudent = (struct StudentTag *)lua_touserdata(L, 1);
	luaL_argcheck(L, pStudent != NULL, 1, "Wrong Parameter");
	lua_pushstring(L, pStudent->strName);
	return 1;
}

static int SetName(lua_State *L)
{
	// ��һ��������userdata
	struct StudentTag *pStudent = (struct StudentTag *)lua_touserdata(L, 1);
	luaL_argcheck(L, pStudent != NULL, 1, "Wrong Parameter");

	// �ڶ���������һ���ַ���
	const char *pName = luaL_checkstring(L, 2);
	luaL_argcheck(L, pName != NULL && pName != "", 2, "Wrong Parameter");

	pStudent->strName = pName;
	return 0;
}

static int GetAge(lua_State *L)
{
	struct StudentTag *pStudent = (struct StudentTag *)lua_touserdata(L, 1);
	luaL_argcheck(L, pStudent != NULL, 1, "Wrong Parameter");
	lua_pushinteger(L, pStudent->iAge);
	return 1;
}

static int SetAge(lua_State *L)
{
	struct StudentTag *pStudent = (struct StudentTag *)lua_touserdata(L, 1);
	luaL_argcheck(L, pStudent != NULL, 1, "Wrong Parameter");

	int iAge = luaL_checkinteger(L, 2);
	luaL_argcheck(L, iAge >= 6 && iAge <= 100, 2, "Wrong Parameter");
	pStudent->iAge = iAge;
	return 0;
}

static int GetSex(lua_State *L)
{
	// ��������������
	return 1;
}

static int SetSex(lua_State *L)
{
	// ��������������
	return 0;
}

static int GetNum(lua_State *L)
{
	// ��������������
	return 1;
}

static int SetNum(lua_State *L)
{
	// ��������������
	return 0;
}

static struct luaL_reg arrayFunc[] =
{
	{"new", Student},
	{"getName", GetName},
	{"setName", SetName},
	{"getAge", GetAge},
	{"setAge", SetAge},
	{"getSex", GetSex},
	{"setSex", SetSex},
	{"getNum", GetNum},
	{"setNum", SetNum},
	{NULL, NULL}
};

int luaopen_userdatademo1(lua_State *L)
{
	luaL_register(L, "Student", arrayFunc);
	return 1;
}