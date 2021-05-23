//load components for express server
const express = require('express')
const app = express()
const port = process.env.PORT || 8888

//this function allows us to return a 2 digit number on the single digit the Date object generates
let formatNumber = (val) => {
  if (val > 9) {
    return val;
  }
  else {
    return (`0${val + 1}`).slice(-2)
  }
}

// Simple function to parse a string then append date and time and return json
let generateDatedResponse = (msg) => {
  // create a date object that we can use to return formatted date
  let now = new Date();

  // format response as json
  let response = {
    message: msg,
    date: `${now.getFullYear()}-${formatNumber(now.getMonth())}-${formatNumber(now.getDate())}`,
    time: `${now.getHours()}:${formatNumber(now.getMinutes())}:${formatNumber(now.getSeconds())}`
  }
  return response;
}

// this function logs our request to console
let logRequest = (req, res, next) => {
  let ip = req.ip
  let route = req.url
  let resp = generateDatedResponse(`${req.ip} requested page ${req.url}`)
  resp.ip = ip
  resp.route = route
  resp.status = res.statusCode
  console.info(JSON.stringify(resp))
  next()
}

// this loads the logging function into our express app and calls it as middleware. This allows for easier expansion of our logging functions as the application matures
app.use(logRequest)

// root of webapp retruns a basic json with "Hello world" and runs it through a helper function to append the date and time
app.get('/', (req, res) => {
  resp = generateDatedResponse("Hello world")
  res.json(resp)
})

//a health check that will return a response if the application is live 
app.get('/health', (req, res) => {
  resp = generateDatedResponse("Health check passed")
  res.json(resp)
}) 

// This is so we can get a correct source IP on kubernetes - currently just piping in service IP CIDR, cluster CIDR & machine network, logging function should be refined to allow for detection regardless of environment
app.set('trust proxy', 'loopback, linklocal, uniquelocal, 172.21.0.0/16, 172.17.0.0/18, 10.242.0.0/16')

//listen on port defined above 
app.listen(port, () => {
  console.log(`${new Date()}\nHello world now listening on port ${port}`)
})
