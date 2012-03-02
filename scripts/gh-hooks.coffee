# Subscribe to github events
# Requires HUBOT_URL="...your_url..." to be set
# requires github-credentials



module.exports = (robot) ->
  robot.brain.on 'loaded', =>
    robot.brain.data.gh-hooks = {}


  robot.router.post '/hubot/gh-hooks', (req, res) ->
    robot.logger.debug "body: #{req.body}"
    robot.logger.debug req._body
    buf = ''
    req.on 'data', (chunk) -> 
      buf += chunk
      robot.logger.debug buf

    req.on 'end', ->
      req.body = JSON.parse(buf);

      res.end buf

  robot.respond /gh-hooks add (.*) (push)/, (msg) ->


    robot.brain.data.gh-hooks
    for k of msg
      robot.logger.debug "#{k}: #{msg[k]}"

    robot.logger.debug "Message:"
    for k of msg.message
      robot.logger.debug "\t#{k}: #{msg.message[k]}"
    robot.logger.debug "User:"
    for k of msg.message.user
      robot.logger.debug "\t#{k}: #{msg.message.user[k]}"
    msg.reply "Subscribing to #{msg.match[2]} events for #{msg.match[1]}"

