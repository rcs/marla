# Subscribe to github events
# Requires HUBOT_URL="...your_url..." to be set



module.exports = (robot) ->
  robot.respond /hub-hooker (.*) (push)/, (msg) ->
    process.stderr.write "Message:"
    process.stderr.write "\t#{a}: #{msg[a]}" for a in msg
    msg.reply "Subscribing to #{match[2]} events for #{match[1]}"

