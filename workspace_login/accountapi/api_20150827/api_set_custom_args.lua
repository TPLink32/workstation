-- 版权声明：暂无
-- 文件名称：api_set_custom_args.lua
-- 创建者  ：梅树义
-- 创建日期：2015/05/12
-- 文件描述：本文件主要为更新/设置设备开机参数
-- 历史记录：无
--

local ngx = require('ngx')
local only = require('only')
local msg = require('msg')
local gosay = require('gosay')
local redis_pool_api = require('redis_pool_api')
local mysql_pool_api = require('mysql_pool_api')
local utils = require('utils')
local app_utils = require('app_utils')
local safe = require('safe')

local sql_fmt = {

	sel_args = "SELECT accountID,model,call1,call2,domain,port,customArgs,updateTime FROM configInfo WHERE model='%s' AND accountID='%s'",
	upd_args = "UPDATE configInfo SET customArgs='%s',remark='%s', updateTime='%s', domain='%s' WHERE accountID='%s' AND model='%s'",
	ins_args = "INSERT INTO configInfo(accountID,model,call1,call2,domain,port,customArgs,createTime,updateTime,remark) values('%s','%s','%s','%s','%s',%d,'%s','%s','%s','%s')",
	ins_config_history = "INSERT INTO configHistory(accountID,model,call1,call2,domain,port,customArgs,updateTime) values('%s','%s','%s','%s','%s',%d,'%s','%s')",
	sl_model = "SELECT model from modelInfo where model = '%s'",

}

local url_info = {
    type_name = 'system',
    app_key = nil,
    client_host = nil,
    client_body = nil,
}
-- 检查参数
local function check_parameter(args)

	if not args['appKey'] and #args['appKey'] > 10 then
		only.log("E", "appKey is error!")
		gosay.go_false(url_info, msg['MSG_ERROR_REQ_ARG'], "appKey")
	end

	url_info['app_key'] = args['appKey']

	safe.sign_check(args, url_info)

	-- check accountID
	if args['accountID'] and args['accountID'] ~= '' then
		if not app_utils.check_accountID(args['accountID']) then
			only.log("E","accountID is error , %s", args['accountID'])
			gosay.go_false(url_info, msg['MSG_ERROR_REQ_ARG'], "accountID")
		end
	end

	-- check model
	if not args['model'] or #args['model'] == 0 then
		only.log("E", "model is error!")
		gosay.go_false(url_info, msg['MSG_ERROR_REQ_ARG'], "model")
	end

	-- check domain
	if not args['domain'] or #args['domain'] == 0 then
		only.log("E", "domain is error!")
		gosay.go_false(url_info, msg['MSG_ERROR_REQ_ARG'], "domain")
	end

	-- check customArgs
	if not args['customArgs'] or #args['customArgs'] == 0 then
		only.log("E", "customArgs is error!")
		gosay.go_false(url_info, msg['MSG_ERROR_REQ_ARG'], "customArgs")
	end
	local ok = nil
	ok,args['customArgs'] = utils.json_decode(args['customArgs'])
	if not ok then
		only.log("E", "customArgs decode is error!")
		gosay.go_false(url_info, msg["MSG_ERROR_REQ_ARG"],"customArgs decode")
	end

	if type(args['customArgs']) ~= 'table' then
		only.log("E", "customArgs table is error!")
		gosay.go_false(url_info, msg['MSG_ERROR_REQ_ARG'], "customArgs table")
	end

	ok, args['customArgs'] = utils.json_encode(args['customArgs'])
	if not ok then
		only.log("E", "customArgs encode is error!")
		gosay.go_false(url_info, msg["MSG_ERROR_REQ_ARG"], "customArgs encode")
	end
	return args
end


local function setCustomArgs(args)
	local tab = {
		call1Number = 10086,
		call2Number = 10086,
	--	domain = 's9d1.mirrtalk.com', 
		port = 80,
	}

	local cur_time = os.time()
	local insert_tab = {}
	local update_tab = {}

	-- 从modelInfo表中查询,检查model是否存在
	local sql = string.format(sql_fmt.sl_model, args['model'])
	local ok, ret = mysql_pool_api.cmd('app_ident___ident', 'select', sql)
	if not ok or ret == nil then
		only.log('E', sql)
		gosay.go_false(url_info, msg["MSG_DO_MYSQL_FAILED"])
	end
	if #ret == 0 then
		only.log('E','model is not exists , %s', args['model'])
		gosay.go_false(url_info, msg["MSG_ERROR_DEVICE_MODEL_INVALID"])
	end

	-- 获取config信息
	local sql = string.format(sql_fmt.sel_args, args['model'],args['accountID'])
	local ok, res = mysql_pool_api.cmd('app_mirrtalk___config', 'select', sql)

	if not ok or ret == nil then
		only.log("E", sql)
		gosay.go_false(url_info, msg["MSG_DO_MYSQL_FAILED"])
	end
	-- 用户之前没有设置参数，设置传入的参数
	if #res == 0 then
		local sql = string.format(sql_fmt.ins_args, args['accountID'], args['model'], tab['call1Number'], tab['call2Number'], args['domain'], tab['port'] ,args['customArgs'],cur_time,cur_time,args['remark'])
		-- only.log('D',sql)
		table.insert(insert_tab,sql)

		local ok,ret = mysql_pool_api.cmd('app_mirrtalk___config','affairs',insert_tab)
		if not ok then
			only.log('E','commit insert failed, %s', sql)
			gosay.go_false(url_info, msg["MSG_DO_MYSQL_FAILED"])
		end
	-- 用户之前设置过开机参数
	else
		-- 首先更新config_history，但若accountID为空，则不更新config_history
		if res['accountID'] and #res[1]['accountID'] == 10 then
			local sql = string.format(sql_fmt.ins_config_history, res[1]['accountID'], res[1]['model'], res['call1Number'], res['call2Number'], res[1]['domain'], res['port'],res[1]['customArgs'],res[1]['updateTime'])
			-- only.log('D',sql)
			local ok = mysql_pool_api.cmd('app_mirrtalk___config', 'INSERT', sql)
			-- only.log('D',res)
			if not ok then
				only.log('E','commit insert config_history failed, %s', sql)
				gosay.go_false(url_info, msg["MSG_DO_MYSQL_FAILED"])
			end
		end

		local sql = string.format(sql_fmt.upd_args, args['customArgs'], args['remark'], cur_time, args['domain'], args['accountID'], args['model'])
		-- only.log('D',sql)
		table.insert(update_tab,sql)

		local ok = mysql_pool_api.cmd('app_mirrtalk___config','affairs',update_tab)
		if not ok then
			only.log('E','commit update failed, %s', sql)
			gosay.go_false(url_info, msg["MSG_DO_MYSQL_FAILED"])
		end
	end
	local ok = nil
	ok,args['customArgs'] = utils.json_decode(args['customArgs'])
	if not ok then
		gosay.go_false(url_info, msg["MSG_ERROR_REQ_ARG"], "encode" )
	end
end

local function handle()
	local pool_body = ngx.req.get_body_data()
	local ip = ngx.var.remote_addr

	url_info['client_host'] = ip
	url_info['client_body'] = pool_body

	if not pool_body or #pool_body == 0 then
		gosay.go_false(url_info, msg['MSG_ERROR_REQ_NO_BODY'])
	end
	local args = utils.parse_url(pool_body)
	-- 检查参数
	args = check_parameter(args)

	args['accountID'] = args['accountID'] or ''
	args['remark']=args['remark'] or ''

	setCustomArgs(args)

	local ok, ret = utils.json_encode(args)
	if not ok then
		gosay.go_false(url_info, msg["SYSTEM_ERROR"])
	end

	gosay.go_success(url_info, msg['MSG_SUCCESS_WITH_RESULT'], ret)


end

safe.main_call( handle )