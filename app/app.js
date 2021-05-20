//load components for express server
const express = require('express')
const app = express()
const port = 8888

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

// root of webapp retruns a basic json with "Hello world" and runs it through helper functions
app.get('/', (req, res) => {
  resp = generateDatedResponse("Hello world")
  res.json(resp)
})

//listen on port defined above 
app.listen(port, () => {
  console.log(`Hello world now listening at http://localhost:${port}`)
})
