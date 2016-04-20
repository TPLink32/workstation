-- local common_path = './?.lua;../public/?.lua;../include/?.lua;'
-- package.path = common_path .. package.path

-- modified in 2015.05.10 by meishuyi 

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

    sel_args = "SELECT call1 FROM configInfo WHERE model='%s' AND accountID='%s' LIMIT 1",
    upd_args = "UPDATE configInfo SET customArgs='%s',remark='%s', updateTime='%s' WHERE accountID='%s' AND model='%s'",
    upd_history_args = "UPDATE configHistory SET customArgs='%s', updateTime='%s' WHERE accountID='%s' AND model='%s'",
    ins_args = "INSERT INTO configInfo(accountID,model,call1,call2,domain,port,customArgs,createTime,updateTime,remark) values('%s','%s','%s','%s','%s',%d,'%s','%s','%s','%s')",
    ins_config_history = "INSERT INTO configHistory(accountID,model,call1,call2,domain,port,customArgs,updateTime) values('%s','%s','%s','%s','%s',%d,'%s','%s')",

}

local url_info = {
    type_name = 'system',
    app_key = nil,
    client_host = nil,
    client_body = nil,
}

local function check_parameter(str)

	local args = utils.parse_url(str)
	url_info['app_key'] = args['appKey']

	-- check accountID
	if args['accountID'] then
		if #args['accountID']>0 then
		    if not app_utils.check_accountID(args['accountID']) then
			gosay.go_false(url_info, msg['MSG_ERROR_REQ_ARG'], "accountID")
		    end
		end
	end
	args['accountID']=args['accountID'] or ''

	-- check model
	if not args['model'] or #args['model'] == 0 then
		gosay.go_false(url_info, msg['MSG_ERROR_REQ_ARG'], "model")
	end
	-- check customArgs
	if not args['customArgs'] then
		gosay.go_false(url_info, msg['MSG_ERROR_REQ_ARG'], "customArgs")
	end

	args['remark']=args['remark'] or ''

	safe.sign_check(args, url_info)

	return args
end


local function func(args)

	local tab = {
		call1Number = 10086,
		call2Number = 10086,
		domain = 's9c0.mirrtalk.com', 
		port = 80, 
	}

	local cur_time = os.time()
	local insert_tab = {}
	local update_tab = {}

	local sql = string.format(sql_fmt.sel_args, args['model'],args['accountID'])
	--only.log('D',"select _sql:%s", sql)
	local ok, res = mysql_pool_api.cmd('app_mirrtalk___config', 'select', sql)
	--only.log('D',"select_res:%s",res)
	if not ok then
		gosay.go_false(url_info, msg["MSG_DO_MYSQL_FAILED"])
	end

	if #res == 0 then
	 	local sql = string.format(sql_fmt.ins_args, args['accountID'], args['model'], tab['call1Number'], tab['call2Number'], tab['domain'], tab['port'] ,args['customArgs'],cur_time,cur_time,args['remark'])
		only.log('D',sql)
		table.insert(insert_tab,sql)

		local sql = string.format(sql_fmt.ins_config_history, args['accountID'], args['model'], tab['call1Number'], tab['call2Number'], tab['domain'], tab['port'],args['customArgs'],cur_time)
	--	only.log('D',sql)
		table.insert(insert_tab,sql)

		local ok,ret = mysql_pool_api.cmd('app_mirrtalk___config','affairs',insert_tab)
		if not ok then
			only.log('E','commit insert failed')
		end

	else
		local sql = string.format(sql_fmt.upd_args, args['customArgs'], args['remark'], cur_time, args['accountID'], args['model'])
		only.log('D',sql)
		table.insert(update_tab,sql)

		local sql = string.format(sql_fmt.upd_history_args, args['customArgs'],cur_time,args['accountID'], args['model'])
	--	only.log('D',sql)
		table.insert(update_tab,sql)

		local ok,ret = mysql_pool_api.cmd('app_mirrtalk___config','affairs',update_tab)
		if not ok then
			only.log('E','commit update failed')
		end

	end
end

local function handle()

	local pool_body = ngx.req.get_body_data()
	local ip = ngx.var.remote_addr

	url_info['client_host'] = ip
	url_info['client_body'] = pool_body

	if not pool_body then
		gosay.go_false(url_info, msg['MSG_ERROR_REQ_NO_BODY'])
	end

	local args = check_parameter(pool_body)

	func(args)

	ok,args['customArgs'] = utils.json_decode(args['customArgs'])

	local ok, ret = utils.json_encode(args)

	gosay.go_success(url_info, msg['MSG_SUCCESS_WITH_RESULT'], ret)


end

safe.main_call( handle )