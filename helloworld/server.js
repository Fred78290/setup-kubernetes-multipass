var http = require('http');
const port = process.env.LISTEN_PORT || 8080;
const podname = process.env.POD_NAME || 'alone';

var handleRequest = function(request, response) {
  console.log('Received request for URL: ' + request.url);
  response.writeHead(200);
  response.end('Hello World from pod ' + process.env.POD_NAME + '!');
};

var www = http.createServer(handleRequest);
www.listen(port);