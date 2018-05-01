pragma solidity ^0.4.21;
import "./Arbiter.sol";
import "./usingOraclize.sol";


contract ComputationService is usingOraclize {
  struct Query {
    string URL;
    string JSON;
  }

  mapping (uint => Query) public computation;

  struct Request {
    string input;
    uint operation;
    uint computationId;
    string result;
    address arbiter;
  }

  mapping (uint => bytes32) public requestId;
  mapping (bytes32 => Request) public requestOraclize;

  address public arbiter;
  bytes32 id;

  event newOraclizeQuery(string description);
  event newResult(string comp_result);
  event newOraclizeID(bytes32 ID);

  function ComputationService() public {
    /* OAR = OraclizeAddrResolverI(0x6f485C8BF6fc43eA212E93BBF8ce046C7f1cb475); */
  }

  function __callback(bytes32 _oraclizeID, string _result) public {
    require(msg.sender == oraclize_cbAddress());
    emit newResult(_result);

    requestOraclize[_oraclizeID].result = _result;

    Arbiter myArbiter = Arbiter(requestOraclize[_oraclizeID].arbiter);
    myArbiter.receiveResults.gas(100000)(_result, requestOraclize[_oraclizeID].computationId);
  }

  function compute(string _val, uint _operation, uint _computationId) public payable {
    bytes32 oraclizeID;
    setcallback();
    computation[_operation].JSON = _val;

    emit newOraclizeQuery("Oraclize query was sent, standing by for the answer.");

    oraclizeID = oraclize_query("URL", computation[_operation].URL, computation[_operation].JSON, 2000000);
    id = oraclizeID;
    requestOraclize[oraclizeID].input = _val;
    requestOraclize[oraclizeID].operation = _operation;
    requestOraclize[oraclizeID].computationId = _computationId;
    requestOraclize[oraclizeID].arbiter = msg.sender;

    requestId[_computationId] = oraclizeID;

    emit newOraclizeID(oraclizeID);
  }

  /* function stringToBytes(string s) internal returns (bytes b) {
    b = bytes(s);
  } */

  function registerOperation(uint _operation, string _query) public {
    if(_operation == 0){
      Query memory twoInt = Query(_query, "");
      computation[0] = twoInt;
    }
  }

  function enableArbiter(address _arbiterAddress) public {
    arbiter = _arbiterAddress;
    Arbiter myArbiter = Arbiter(_arbiterAddress);
    myArbiter.enableService();
  }

  function disableArbiter(address _arbiterAddress) public {
    delete arbiter;
    Arbiter myArbiter = Arbiter(_arbiterAddress);
    myArbiter.disableService();
  }

  function getResult(uint _computationId) public constant returns (string) {
    return requestOraclize[requestId[_computationId]].result;
  }

  function getArbiter(uint _computationId) public constant returns (address) {
    return requestOraclize[requestId[_computationId]].arbiter;
  }

  function getcomptation(uint _operation) public constant returns (string,string){
    return (computation[_operation].URL,computation[_operation].JSON);
  }

  function getOraclizeID() public constant returns (bytes32 _id) {
    _id = id;
  }

  function setcallback() public payable {
    oraclize_setCustomGasPrice(1 wei);
  }

  function getRequestId(uint _computationId) public view returns (bytes32 _id) {
    _id = requestId[_computationId];
  }

  function getRequestInfo(bytes32 _id) public constant returns (string _input, uint _operation, uint _computationId, string _result) {
    _input = requestOraclize[_id].input;
    _operation =  requestOraclize[_id].operation;
    _computationId = requestOraclize[_id].computationId;
    _result = requestOraclize[_id].result;
  }
}
