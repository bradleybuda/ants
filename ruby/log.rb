require 'syslog'

LOG = false

$last_log = Time.now.to_f
def log(message)
  if LOG
    now = Time.now.to_f
    interval = ((now - $last_log) * 1000).to_i
    $last_log = now
    formatted = "[%d] [%.3f] [+%03d] %s" % [AI.instance.turn_number, now, interval, message]
    Syslog.open($0, Syslog::LOG_PID | Syslog::LOG_CONS) { |s| s.notice formatted }
  end
end
