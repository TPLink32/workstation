-- author: zhangjl
-- date: 2014 04 14 Wed 10:44:20 CST

local ngx = require 'ngx'
local only = require 'only'
local gosay = require 'gosay'
local utils = require 'utils'
local app_utils = require 'app_utils'
local msg = require 'msg'
local weibo_fun = require 'weibo_fun'
local safe = require('safe')

local mysql_pool_api = require 'mysql_pool_api'
local redis_pool_api = require 'redis_pool_api'

local url_info = {
	type_name = 'system',
	app_key = nil,
	client_host = nil,
	client_body = nil,
}

local function set_user_weibo(args_tab, receive_user, refused_user, level)

	local key, val, ok, ret

	key = string.format('%s:%s', args_tab['bizid'], 'weibo')
	ok, val = utils.json_encode(args_tab)
	local expire_time  = args_tab['interval'] or 300

	if args_tab['groupID'] == "000001312"  then
		only.log('E', string.format('xxxxxxxx setex key:%s time:%s value:%s', key, expire_time ,val))
	end
	only.log('D', string.format('setex key:%s time:%s value:%s', key, expire_time ,val))
	ok, ret = redis_pool_api.cmd('weibo', 'setex', key, expire_time, val)
	if not ok then
		only.log('E', string.format('setex key:%s time:%s value:%s', key, expire_time, val))
		return false
	end


	for k, v in pairs(receive_user) do

		if refused_user ~= v then

			key = string.format('%s:%s', v, 'weiboPriority')

			only.log('D', string.format('zadd %s %s %s', key, level .. args_tab['time'][1],  args_tab['bizid']))
			if v == "HRlYQhFvpW" or v == "egQH09ks9a" then
				only.log('E', string.format('lipengwei group zadd group  %s %s %s', key, level .. args_tab['time'][1],  args_tab['bizid']))
			end
			ok, ret = redis_pool_api.cmd('weibo', 'zadd', key, level .. args_tab['time'][1],  args_tab['bizid'])
			if not ok then
				break
			end
		end
	end

end

local function get_group_user(group_id, child_tab)
	local ret_tab = {}
	--modity add by jiang z.s. 2014-05-01  and validity = 1
	local sql = string.format("SELECT distinct accountID  FROM userGroupInfo WHERE groupID='%s'  and validity = 1  ", group_id)
	only.log('D', sql)
	local ok, res = mysql_pool_api.cmd('app_weibo___weibo', 'SELECT', sql)
	if not ok then
		return ret_tab
	end

	for _, v in ipairs(res) do
		table.insert(ret_tab, v['accountID'])
	end

	-- get the cross set
	if child_tab then
		local parent_str = table.concat(ret_tab, ',')
		for k, v in ipairs (child_tab) do
			if not string.find(parent_str, v) then
				table.remove(child_tab, k)
			end
		end

		ret_tab = child_tab
	end

	return ret_tab
end

local function touch_redis(args_tab)


	-- %s is special in redis
	local media_url = utils.escape_redis_text(args_tab['multimediaURL'])

	local js_tab = {

		multimediaFileURL = media_url,
		time = {args_tab['start_time'], args_tab['end_time']},
		tokenCode = args_tab['tokenCode'],
		groupID = args_tab['groupID'],

		content = args_tab['content'],
		bizid = args_tab['bizid'],
		level = args_tab['level'],
		type = args_tab['messageType'],
		longitude = args_tab['receiverLongitude'],
		latitude = args_tab['receiverLatitude'],
		distance = args_tab['receiverDistance'],
		direction = args_tab['direction_tab'],
		speed = args_tab['speed_tab'],
		tipType = args_tab['tipType'],
	}

	local refused_user
	if args_tab['receiveSelf'] == 0 and args_tab['senderAccountID'] then
		refused_user = args_tab['senderAccountID']
	end

	local level = args_tab['level']


	local sender_info = {
		senderAccountID = args_tab['senderAccountID'],
		callbackURL = args_tab['callbackURL'],
		sourceID = args_tab['sourceID'],
		fileID = args_tab['fileID'],
		appKey = args_tab['appKey'],
		commentID = args_tab['commentID'],
	}

	if next(sender_info) then
		local ok, json_string = utils.json_encode(sender_info)
		if not ok then
			return false
		end

		local key  = string.format("%s:senderInfo",args_tab['bizid']) 
		local value  = json_string
		local expire_time  = args_tab['interval'] or 300


		only.log('D', string.format('setex key:%s expire_time:%s value:%s', key ,expire_time,value))
		ok, ret = redis_pool_api.cmd('weibo', 'setex', key , expire_time , value)
		if not ok then
			only.log('E', string.format('setex key:%s expire_time:%s value:%s', key ,expire_time,value))
			return false
		end

	end
	set_user_weibo(js_tab, args_tab['receive_user'], refused_user, level)

	return #args_tab['receive_user']
end

local function touch_db(args)

	local sql_fmt = "INSERT groupMultimediaWeibo_%s SET appKey=%s,sourceID='%s',sourceType=%s,fileID='%s',multimediaURL='%s'," ..
	"senderAccountID='%s',senderLongitude=%s,senderLatitude=%s,senderDirection='%s',senderSpeed='%s',senderAltitude=%s,cityCode=%s,cityName='%s'," ..
	"groupID='%s',receiveCrowd='%s',receiveSelf=%s,receiverLongitude=%s,receiverLatitude=%s,receiverDirection='%s',receiverSpeed='%s',receiverDistance=%s," ..
	"content='%s',startTime=%d,endTime=%d,level=%d,checkTokenCode=%d,tokenCode='%s',callbackURL='%s',createTime=%d,bizid='%s',messageType=%d"

	local cur_month = os.date('%Y%m')

	local media_url = utils.escape_mysql_text(args['multimediaURL'])
	local sender_lon = args['senderLongitude'] and args['senderLongitude'] * 10000000 or 0 
	local sender_lat = args['senderLatitude'] and args['senderLatitude'] * 10000000 or 0 
	local receiver_lon = args['receiverLongitude'] and args['receiverLongitude'] * 10000000 or 0 
	local receiver_lat = args['receiverLatitude'] and args['receiverLatitude'] * 10000000 or 0 

	local city_code, city_name, json_tab
	if sender_lon~=0 and sender_lat~=0 then
		local grid_no = string.format('%d&%d', math.floor(args['senderLongitude']*100), math.floor(args['senderLatitude'] * 100))

		only.log('D', grid_no)
		local ok, ret = redis_pool_api.cmd('mapGridOnePercent', 'get', grid_no)
		if ok then
			city_code = ret 
			ok, json_tab = utils.json_decode(ret)
		end 
		if ok then
			city_code, city_name = json_tab['cityCode'], json_tab['cityName']
		end 
	end 


	local sql = string.format(sql_fmt, cur_month, args['appKey'], args['sourceID'] or '', args['sourceType'], args['fileID'] or '', media_url,
	args['senderAccountID'] or '', sender_lon, sender_lat, args['senderDirection'] or '', args['senderSpeed'] or '', args['senderAltitude'] or -9999, city_code or 0, city_name or '',
	args['groupID'] or '', args['receiveCrowd'] or '', args['receiveSelf'], receiver_lon, receiver_lat, args['receiverDirection'] or '', args['receiverSpeed'] or 0, args['receiverDistance'] or 0,
	args['content'] or '', args['start_time'], args['end_time'], args['level'], args['checkTokenCode'] or 0, args['tokenCode'] or '', args['callbackURL'] or '', args['start_time'], args['bizid'], args['messageType'] or 0)


	only.log('D', sql)
	local ok, ret = mysql_pool_api.cmd('app_weibo___weibo', 'INSERT', sql)
	if not ok then
		gosay.go_false(url_info, msg["MSG_DO_MYSQL_FAILED"])
	end

end

local function check_parameters(tab)

	url_info['app_key'] = tab['appKey']

	if not tab['groupID'] then
		gosay.go_false(url_info, msg["MSG_ERROR_REQ_ARG"], "groupID")
	end

	if tab['receiveCrowd'] then
		local ok, res = utils.json_decode( tab['receiveCrowd'])
		if not ok then
			gosay.go_false(url_info, msg["MSG_ERROR_REQ_ARG"], "receiveCrowd")
		end
		if res['accountID'] then
			tab['receive_user'] = res['accountID']

			------最大接口数组应该小于50
			if type(tab['receive_user'])~='table' or #tab['receive_user']>50 then
				gosay.go_false(url_info, msg["MSG_ERROR_REQ_ARG"], "receiveCrowd accountID")
			end
		end
	end

	-->> check interval
	tab['interval'] = tonumber(tab['interval'])
	if not tab['interval'] or tab['interval'] < 0 then
		gosay.go_false(url_info, msg["MSG_ERROR_REQ_ARG"], "interval")
	end

	-- about the source type, 1 represent the url, 2 represent the file
	local multimedia_url, source_type, file_id

	-- don't include multimediaFile when compute this argument, so set it nil
	if tab['multimediaURL'] then
		if not string.match(tab['multimediaURL'], 'http://[%w%.]+:?%d*/.+') and  not string.match(tab['multimediaURL'], 'redis://') then
			gosay.go_false(url_info, msg["MSG_ERROR_REQ_ARG"], "multimediaURL")
		end
		multimedia_url = tab['multimediaURL']
		source_type = 1
	end

	if not tab['multimediaURL'] then
		if not tab['multimediaFile'] then
			gosay.go_false(url_info, msg["MSG_ERROR_REQ_ARG"], "multimediaFile or multimediaURL")
		end
		file_id, multimedia_url = weibo_fun.get_dfs_url(tab['multimediaFile'], tab['appKey'])
		if not multimedia_file_url  then
			gosay.go_false(url_info, msg["MSG_DO_HTTP_FAILED"])
		end

		source_type = 2
		tab['multimediaFile'] = nil
	end

	-->> check appKey and sign
	safe.sign_check(tab, url_info)

	tab['fileID'] = file_id
	tab['multimediaURL'] = multimedia_url
	tab['sourceType'] = source_type

	tab['receiveSelf'] = tonumber(tab['receiveSelf']) or 1
	if tab['receiveSelf']~=0 and tab['receiveSelf']~=1 then
		gosay.go_false(url_info, msg["MSG_ERROR_REQ_ARG"], "receiveSelf")
	end

	-->> check level
	tab['level'] = tonumber(tab['level']) or 99
	if tab['level']>99 or tab['level']<1 then
		gosay.go_false(url_info, msg["MSG_ERROR_REQ_ARG"], "level")
	end

	local ok, res1, res2
	ok, res1 = weibo_fun.check_geometry_attr(tab['senderLongitude'], tab['senderLatitude'], tab['senderAltitude'], tab['senderDistance'], tab['senderDirection'], tab['senderSpeed'], 'sender')
	if not ok then
		gosay.go_false(url_info, msg["MSG_ERROR_REQ_ARG"], res1)
	end

	-- because this tab is used in the store of redis
	ok, res1, res2 = weibo_fun.check_geometry_attr(tab['receiverLongitude'], tab['receiverLatitude'], tab['receiverAltitude'], tab['receiverDistance'], tab['receiverDirection'], tab['receiverSpeed'], 'receiver')
	if not ok then
		gosay.go_false(url_info, msg["MSG_ERROR_REQ_ARG"], res1)
	end

	tab['direction_tab'], tab['speed_tab'] = res1, res2


	if tab['senderAccountID'] then
		if not app_utils.check_accountID(tab['senderAccountID']) and not app_utils.check_imei(tab['senderAccountID']) then
			gosay.go_false(url_info, msg["MSG_ERROR_REQ_ARG"], "senderAccountID")
		end
	end

	if tonumber(tab['checkTokenCode'])==1 then
		local ok, imei
		if #tab['receiverAccountID'] == 15 then
			imei = tab['receiverAccountID']
		else
			ok, imei = redis_pool_api.cmd('private', 'get', tab['receiverAccountID'] .. ':IMEI')
		end

		local ok, res = redis_pool_api.cmd('private', 'get', (imei or '') .. ':tokenCode')
		if ok and res then
			tab['tokenCode'] = res
		end
	end

	-- tab['callbackURL'], nothing to do with this argc

	tab['startTime'] = tonumber(tab['startTime'])
	if tab['startTime'] and (os.time() - tab['startTime'] < 120) then
		tab['start_time'] = tab['startTime']
	else
		tab['start_time'] = os.time()
	end
	tab['end_time'] = os.time() + tab['interval']

	if tab['end_time'] <= tab['start_time'] then
		gosay.go_false(url_info, msg["MSG_ERROR_REQ_ARG"], "startTime")
	end

	if tab['content'] then
		tab['content'] = utils.url_decode(tab['content'])
	end

	if tab['messageType'] and tonumber(tab['messageType'])==1 then
		tab['messageType'] = 2
	else
		tab['messageType'] = 3
	end

	if tab['commentID'] and #tab['commentID']>32 then
		gosay.go_false(url_info, msg["MSG_ERROR_REQ_ARG"], "commentID")
	end

	tab['tipType'] = tonumber(tab['tipType']) or 0

	if not (tab['tipType'] == 0 or tab['tipType']== 1) then 
		gosay.go_false(url_info, msg["MSG_ERROR_REQ_ARG"], "tipType")
	end

	tab['channelSoundMode'] = tonumber(tab['channelSoundMode']) or 1

	tab['skipChannelAuthorize'] = tonumber(tab['skipChannelAuthorize']) or 0
end

local function get_redis_user(group_id)

	local ok, res = redis_pool_api.cmd('statistic', 'smembers', (group_id or '') .. ':channelOnlineUser')
	return res
end
local function testlog( body_str )
	local str = body_str
	local str1 = os.date("%Y%m%d-%H:%M:%S")
	local file = io.open("/tmp/result.txt","a")
	file:write(str..str1.."\n")
	io.close(file)

end

local function handle()
	local req_heads = ngx.req.raw_header()
	local req_body = ngx.req.get_body_data()
	local ip = ngx.var.remote_addr

	url_info['client_host'] = ip
	url_info['client_body'] = req_body

	if not req_body then
		gosay.go_false(url_info, msg["MSG_ERROR_REQ_NO_BODY"])
	end

	local body_args = utils.parse_form_data(req_heads, req_body)
	if not body_args then
		gosay.go_false(url_info, msg["MSG_ERROR_REQ_ARG"], "Content-Type")
	end
	if body_args['groupID'] == "000001312"  then
		--body_args['interval'] = '120'
		only.log('E', 'xxxxxxxxxx111')
	end


	check_parameters(body_args)
	if body_args['groupID'] == "000001312"  then
		only.log('E','xxxxxxxxx222')
	end

	if body_args['skipChannelAuthorize'] == 0 then
		body_args['receive_user'] = get_group_user(body_args['groupID'], body_args['receive_user'])
	elseif not body_args['receive_user'] or #body_args['receive_user'] == 0 then
		body_args['receive_user'] = get_redis_user(body_args['groupID'])
	end

	if #body_args['receive_user'] == 0 then
		gosay.go_false(url_info, msg['MSG_ERROR_GROUP_ID_NOT_EXIST'])
	end

	body_args['bizid'] = weibo_fun.create_bizid('a2')
	weibo_fun.group_save_message_to_msgredis(body_args)
	if body_args['groupID'] == "000001312"  then
		only.log('E', 'xxxxxxxxxx333')
	end

	local cnt = 0
	if body_args['channelSoundMode'] == 1 then
		cnt = touch_redis(body_args)
	end

	---- 2014-10-14  统计appkey发送微博总数
	local cur_month = os.date('%Y%m')
	local cur_day = os.date("%Y%m%d")
	weibo_fun.incrby_appkey( body_args['appKey'], cur_month, cur_day)
	weibo_fun.incrby_groupid( body_args['groupID'], cur_month, cur_day)


	----频道内最后一次说话时间
	weibo_fun.groupid_update_timestamp( body_args['groupID'] )

	local result = string.format('{"bizid":"%s","count":%d}', body_args['bizid'], cnt or 0)
	gosay.go_success(url_info, msg['MSG_SUCCESS_WITH_RESULT'], result)
end

safe.main_call( handle )