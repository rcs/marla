# Subscribe to github events
# Requires HUBOT_URL="...your_url..." to be set



module.exports = (robot) ->
  robot.respond /hub-hooker (.*) (push)/, (msg) ->
    robot.logger.debug "Message:"
    robot.logger.debug "\t#{a}: #{msg[a]}" for a in msg
    msg.reply "Subscribing to #{msg.match[2]} events for #{msg.match[1]}"

