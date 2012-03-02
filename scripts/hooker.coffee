# Subscribe to github events
# Requires HUBOT_URL="...your_url..." to be set



module.exports = (robot) ->
  robot.respond /hooker (.*) (push)/, (msg) ->
    process.stderr.write JSON.stringify(msg)
    msg.reply "Subscribing to #{match[2]} events for #{match[1]}"

