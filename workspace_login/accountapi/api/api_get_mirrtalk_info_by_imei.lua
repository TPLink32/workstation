--author    : chengjian
--date      : 2014-04-12
-- zhouzhe 2015-08-18 modify
local ngx       = require ('ngx')
local redis_api = require('redis_pool_api')
local mysql_api = require('mysql_pool_api')
local utils     = require('utils')
local cutils    = require('cutils')
local only      = require('only')
local msg       = require('msg')
local gosay     = require('gosay')
local safe      = require('safe')
local cfg       = require('config')

local sql_fmt = {
	sql_check_IMEI = [[SELECT model,imei,nCheck FROM mirrtalkInfo WHERE imei = %s ]],
	check_userlist = [[SELECT accountID FROM userLoginInfo WHERE imei = %s]],
	-- get_update_time = [[SELECT unix_timestamp(updateTime) FROM userListHistory WHERE IMEI='%s' ]]..
	--                     [[AND userStatus=5 ORDER BY updateTime DESC limit 1]],
}

local usercenter_dbname = 'app_usercenter___usercenter'
local userident_dbname = 'app_ident___ident'

local G = {
	legalIMEI = 0,
	usableIMEI = 0,
	accountID = '',
	online = 0,
	nickname = '',
	model='',
}

local url_info = {
	type_name = 'system',
	app_key = nil,
	client_host = nil,
	client_body = nil,
}

local function check_parameter(body)
	-->> check IMEI

	local res = utils.parse_url(body) 

	if not res or type(res) ~= "table" then
		gosay.go_false(url_info, msg["MSG_ERROR_REQ_BAD_JSON"])
	end 

	if not res['appKey'] then
		gosay.go_false(url_info, msg["MSG_ERROR_REQ_CODE"],"appKey is not exist!")
	end 

	url_info['app_key'] = res['appKey']

	if (not utils.is_number(res["IMEI"])) or (string.len(res["IMEI"]) ~= 15) or (string.sub(res["IMEI"], 1, 1) == "0") then
		only.log('D', string.format("check_parameter imei error :%s ",'IMEI'))
		gosay.go_false(url_info, msg["MSG_ERROR_REQ_ARG"], "IMEI")
	end

	safe.sign_check(res, url_info)

	return res
end

local function get_nickname(a_id)
	local ok, name = redis_api.cmd('private', 'get', a_id .. ':nickname')
	if not ok then
		gosay.go_false(url_info, msg["MSG_DO_REDIS_FAILED"]) 
	end

	return name or ''
end

local function check_imei(args)

	local tmp_imei = string.sub(args["IMEI"], 1, 14)
	local tmp_ncheck = string.sub(args["IMEI"], 15, 15)
	local res_sql = string.format(sql_fmt.sql_check_IMEI, tmp_imei)
	only.log('D', res_sql)
	local ok, result = mysql_api.cmd(userident_dbname, 'SELECT', res_sql)
	if not ok then
		gosay.go_false(url_info, msg["MSG_DO_MYSQL_FAILED"]) 
	end

	-- 如果查询结果为空，返回给定的IMEI非法
	if #result == 0 then
		ok, result = utils.json_encode(G)
		gosay.go_success(url_info, msg['MSG_SUCCESS_WITH_RESULT'], result)
	elseif #result > 1 then
		only.log('S', string.format('too many record or imei:%s', args['IMEI']))
		gosay.go_false(url_info, msg["MSG_ERROR_MORE_RECORD"], "IMEI")
	end

	if tonumber(result[1]['nCheck']) ~= tonumber(tmp_ncheck) then
		only.log('E', string.format('ncheck:%s===mysql tmp_ncheck:%s', tmp_ncheck, result[1]['nCheck']))
		gosay.go_false(url_info, msg["MSG_ERROR_REQ_ARG"], "IMEI")
	end

	G['model'] = result[1]['model']
	G["legalIMEI"] = 1

	res_sql = string.format(sql_fmt.check_userlist, args['IMEI'])
	only.log('D', res_sql)
	local ok, result = mysql_api.cmd(usercenter_dbname, 'SELECT', res_sql)
	if not ok then
		gosay.go_false(url_info, msg["MSG_DO_MYSQL_FAILED"]) 
	end

	if #result~=0 then
		G["usableIMEI"] = 0
		G["accountID"] = result[1]['accountID']
		G['nickname'] = get_nickname(G['accountID'])
	elseif #result == 0 then
		G["usableIMEI"] = 1
		G["accountID"] = ''
		G['nickname'] = ''
	end
end

local function get_redis_info( args )

	local ok, user, newstatus_time
	-->> check time

	if G['accountID'] ~= '' then
		user = G['accountID']
	else
		user = args['IMEI']
	end
	ok, newstatus_time = redis_api.cmd('private', 'get', user .. ':heartbeatTimestamp')
	if not ok then
		gosay.go_false(url_info, msg["MSG_DO_REDIS_FAILED"]) 
	end
	if (not newstatus_time) or ((os.time() - tonumber(newstatus_time)) > cfg['user_online_space']) then
		G['online'] = 0
	else
		G['online'] = 1
	end

end

local function handle()

	local body = ngx.req.get_body_data()

	url_info['client_body'] = body
	url_info['client_host'] = ngx.var.remote_addr

	only.log('D',  body)

	-->| STEP 1 |<--
	-->> check parameters
	local res = check_parameter(body)

	-->| STEP 3 |<--
	-->> check imei
	check_imei( res )

	-->> check online
	get_redis_info( res )

	local ok,data = utils.json_encode(G)

	gosay.go_success(url_info, msg['MSG_SUCCESS_WITH_RESULT'], data)
end

safe.main_call( handle )
