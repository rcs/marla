# Subscribe to github events
# Requires HUBOT_URL="...your_url..." to be set



module.exports = (robot) ->
  robot.respond /hub-hooker (.*) (push)/, (msg) ->
    for k of msg
      robot.logger.debug "#{k}: #{msg[k]}"

    robot.logger.debug "Message:"
    for k of msg.message
      robot.logger.debug "\t#{k}: #{msg.message[k]}"
    msg.reply "Subscribing to #{msg.match[2]} events for #{msg.match[1]}"

