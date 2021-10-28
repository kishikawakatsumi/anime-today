require "active_support"
require "active_support/core_ext"
require "sinatra"
require "syoboi_calendar"
require "tmp_cache"

set :bind, "0.0.0.0"
set :port, ENV["PORT"] || 4567

set :cache, TmpCache::Cache.new

before do
  content_type "application/json"
end

get "/" do
  ActiveSupport::JSON.encode({ version: 1.0 }.as_json)
end

get "/channels" do
  group_id = params[:group_id]

  key = "channels[all]"
  if group_id
    key = "channels[#{group_id}]"
  end

  if results = settings.cache.get(key)
    results
  else
    results = channels(group_id)
    settings.cache.set(key, results, 1.hour)
    results
  end
end

get "/programs" do
  channel_ids = params["channel_ids"]

  key = "programs[all]"
  if channel_ids
    key = "programs[#{channel_ids}]"
  end

  if results = settings.cache.get(key)
    results
  else
    results = programs(channel_ids)
    settings.cache.set(key, results, 30.minutes)
    results
  end
end

def client
  @client ||= SyoboiCalendar::Client.new
end

def channels(group_id)
  channels = client.channels

  if group_id
    channels.select! { |channel| channel.group_id == group_id.to_i }
  end

  results = ActiveSupport::JSON.encode({ channels: channels.sort_by { |channel| [channel.group_id, channel.id] } }.as_json)
  results
end

def programs(channel_ids)
  programs = client.programs(program_options(channel_ids))
  programs = { programs: programs.sort_by { |program| [program.started_at, program.channel_id] } }.as_json
  programs = stringify_values(programs)

  results = ActiveSupport::JSON.encode(programs)
  results
end

def stringify_values(obj)
  case obj
  when Array
    obj.map { |e| stringify_values(e) }
  when Hash
    obj.inject({}) do |hash, (k, v)|
      hash[k] = stringify_values(v)
      hash
    end
  when Date
    obj
  when DateTime
    obj
  when Time
    obj
  when Numeric
    obj
  else
    obj.to_s
  end
end

def program_options(channel_ids)
  { played_from: played_from,
    played_to: played_to,
    channel_id: channel_ids,
    includes: [:channel, :title] }.reject { |key, value| value.nil? }
end

def now
  Time.now
end

def played_from
  if now.hour >= 4
    now.beginning_of_day + 4.hour
  else
    now.yesterday.beginning_of_day + 4.hour
  end
end

# 04:00 ~ 28:00
def played_to
  if now.hour >= 4
    now.tomorrow.beginning_of_day + 4.hour
  else
    now.beginning_of_day + 4.hour
  end
end

class SyoboiCalendar::Resources::Channel
  def as_json
    { comment: comment,
      epg_url: epg_url,
      group_id: group_id,
      id: id,
      iepg_name: iepg_name,
      name: name,
      number: number,
      url: url }
  end
end

class SyoboiCalendar::Resources::Program
  def as_json
    { channel_id: channel_id,
      comment: comment,
      count: count,
      deleted: deleted?,
      finished_at: finished_at,
      flag: flag,
      id: id,
      revision: revision,
      started_at: started_at,
      sub_title: sub_title,
      title_id: title_id,
      updated_at: updated_at,
      warn: warn,
      channel: channel.as_json,
      title: title.as_json }
  end
end

class SyoboiCalendar::Resources::Title
  def as_json
    { category_id: category_id,
      comment: comment,
      first_channel: first_channel,
      first_end_month: first_end_month,
      first_end_year: first_end_year,
      first_month: first_month,
      first_year: first_year,
      keywords: keywords,
      short_title: short_title,
      sub_titles: sub_titles,
      id: id,
      name: name,
      english_name: english_name,
      flag: flag,
      kana: kana,
      point: point,
      rank: rank }
  end
end
