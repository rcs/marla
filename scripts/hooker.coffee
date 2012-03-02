# Subscribe to github events
# Requires HUBOT_URL="...your_url..." to be set



module.exports = (robot) ->
  robot.respond /hub-hooker (.*) (push)/, (msg) ->
    robot.logger.debug "User: #{msg.user}"
    robot.logger.debug "User: #{msg.text}"
    msg.reply "Subscribing to #{msg.match[2]} events for #{msg.match[1]}"

