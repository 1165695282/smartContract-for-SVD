pragma solidity ^0.4.21;
import "./ComputationService.sol";

contract Arbiter {

  address public judge;

  struct Request {
    string input;
    uint operation;//一般情况下是０
    address[] solver;
    /* address[] verifier; */
    string[] resultSolver;
    /* string[6] resultVerifier; //最多６个验证者
    bytes32[6] resultVerifierhash;*/
    uint status;
    string finalResult;
    bool finished;
  }

  /* bytes32 public url;
  bytes32 public json; */
  /* struct compareBuffer{
    string data;
    uint count;
  }

  mapping (bytes32 => compareBuffer) public comparebuf;
   */

   mapping ( uint => Request) public requests;
   mapping (address => uint) public currentRequest;

   address[] public service;
   mapping (address => uint) internal serviceIndex;

   mapping (string => uint) resultCount;

   event newRequest(uint newRequest);
   event solverFound(address solver);
   /* event verifierFound(address verifier); */
   event statusChange(uint status);
   event newExecution(uint newExecution);
   event solverExecution(address solver);
   /* event verifierExecution(address verifier); */
   event receiveRequest(string receiveRequest);
   event loopTest(uint helper, uint thisValue);

   function enableService() public {
     uint index;
     service.push(msg.sender);
     index = service.length - 1;
     serviceIndex[msg.sender] = index;
   }

   function disableService() public {

     uint index;
     index = serviceIndex[msg.sender];
     delete service[index];
     serviceIndex[msg.sender] = 0;

     if(index < service.length - 1){
       uint thisIndex;
       uint nextIndex;

       thisIndex = index;
       nextIndex = thisIndex + 1;

       while(thisIndex < service.length - 1){
         service[thisIndex] = service[nextIndex];
         thisIndex ++;
         nextIndex ++;
       }
     }
   }

   function requestComputation(string _input, uint _operation, uint _numProcessor) public {
     address solver;
     /* address verifier; */
     uint computationId;

     uint index;
     uint length = service.length;
     address[] memory remainingService = new address[](length);

     require(_numProcessor < service.length);
     /* require(_numProcessor < 7); */

     remainingService = service;
     computationId = rand(0, 2**64);
     currentRequest[msg.sender] = computationId;

     requests[computationId].input = _input;
     requests[computationId].operation = _operation;

     emit newRequest(computationId);

     for (uint i = 0; i < _numProcessor; i++){
       index = rand(0, length - 1);
       solver = remainingService[index];
       requests[computationId].solver.push(solver);
       emit solverFound(solver);
       for(uint k = index; k < length - 1; k++){
         remainingService[k] = remainingService[k+1];
       }
       length --;

       //计算请求产生，但尚未提交结果
       updateStatus(100, computationId);

       emit statusChange(requests[computationId].status);
     }

     /* index = rand(0, length-1);
     solver = remainingService[index];
     requests[computationId].solver = solver;
     emit solverFound(solver); */

     /* for(uint i = index; i < length-1;i++){
       remainingService[i] = remainingService[i + 1];
     }
     length --; */

     /* for (uint j = 0; j < _numVerifier; j++){
       index = rand(0, length - 1);
       verifier = remainingService[index];
       requests[computationId].verifier.push(verifier);
       emit verifierFOund(verifier);

       for(uint k = index; k < length - 1; k++){
         remainingService[k] = remainingService[k+1];
       }
       length --;

       //计算请求产生，但尚未提交结果
       updateStatus(100, computationId);
       emit statusChange(requests[computationId].status);
     }*/
   }

   function executeComputation() public payable {
     uint computationId = currentRequest[msg.sender];

     require(requests[computationId].status == 100);
     updateStatus(200,computationId);
     emit newExecution(computationId);

     for(uint i = 0;i < requests[computationId].solver.length; i++){
       ComputationService mySolver = ComputationService(requests[computationId].solver[i]);
       mySolver.compute.value(100000000).gas(5000)(requests[computationId].input, requests[computationId].operation, computationId);
       /* url = mySolver.getURL(requests[computationId].operation);
       json = mySolver.getJSON(requests[computationId].operation); */
       emit solverExecution(requests[computationId].solver[i]);
     }

     emit statusChange(requests[computationId].status);
   }

   function receiveResults(string _result, uint256 _computationId) public {
     if(requests[_computationId].status == 100){
       updateStatus(200, _computationId);
     }
     emit receiveRequest(_result);

     uint count = 0;
     for (uint i = 0; i < requests[_computationId].solver.length; i++){
       if(msg.sender == requests[_computationId].solver[i]){
         requests[_computationId].resultSolver[i] = _result;
         count = 1;
         break;
       }
     }

     if(requests[_computationId].status == 200){
       updateStatus((300 + count),_computationId);
     } else {
       updateStatus((requests[_computationId].status + count), _computationId);
     }
     if((requests[_computationId].status - 300) == requests[_computationId].solver.length){
       updateStatus(400, _computationId);//说明所有的结果都已经得到了；
     }

     emit statusChange(requests[_computationId].status);
   }

   function compareResult() public {
      uint computationId = currentRequest[msg.sender];
      require(requests[computationId].status == 400);

      uint length = requests[computationId].solver.length;
      string[] memory result = new string[](length);
      /* string[] memory differResult = new string[](length); */

      for(uint i = 0;i < length;i++){
        result[i] = requests[computationId].resultSolver[i];
      }
      /* differResult.push(result[0]); */

      for(i = 0; i < result.length; i++){
        resultCount[result[i]] = 0;
      }
      resultCount[result[0]] = 1;
      bool isAllAccept = true;
      for(i = 1; i < result.length; i++){
        if(!stringsEqual(result[0],result[i])){
          isAllAccept = false;
        }
        resultCount[result[i]] += 1;
      }
      if(isAllAccept){
        //说明所有结果都相同
        requests[computationId].status = 500;
        requests[computationId].finished = true;
        requests[computationId].finalResult = requests[computationId].resultSolver[0];
      }else {
        requests[computationId].status = 700;
      }

      emit statusChange(requests[computationId].status);
   }

   function judgeBegin() public {
     uint computationId = currentRequest[msg.sender];
     require(requests[computationId].status == 700);

     //半数以上相同的则为正确答案（或取最多的）
     /* uint totalProcessor = requests[computationId].solver.length; */
     uint length = requests[computationId].resultSolver.length;
     string[] memory result = new string[](length);
     for(uint i = 0; i < length; i++){
       result[i] = (requests[computationId].resultSolver[i]);
     }
     uint numResult = 0;
     for(i = 0; i < result.length; i++){
       if(!stringsEqual(result[0],result[i])){
         numResult += 1;
       }
     }

     string[] memory differResult = new string[](numResult);
     differResult[0] = result[0];
     for(i = 1; i < result.length; i++){
       if(!stringsEqual(result[0],result[i])){
         differResult[i] = result[i];
       }
     }

     requests[computationId].finalResult = differResult[0];
     for(i = 1; i < numResult; i++){
       if(resultCount[requests[computationId].finalResult] < resultCount[differResult[i]]){
         requests[computationId].finalResult = differResult[i];
       }
     }
     requests[computationId].finished = true;
     requests[computationId].status = 800;
   }

   function setJudge(address _judge) public {
     judge = _judge;
   }

   function updateStatus(uint newStatus, uint computationId) public {
     requests[computationId].status = newStatus;
   }

   function getInput(address _requester) public view returns (string _input){
     _input = requests[currentRequest[_requester]].input;
   }

   function getStatus(address _requester) public constant returns (uint status) {
     status = requests[currentRequest[_requester]].status;
   }

   function getCurrentSolver(address _requester) public view returns (address[] solver) {
     solver = requests[currentRequest[_requester]].solver;
   }

   function getFinalResult(address _requester) public view returns (string result){
     result = requests[currentRequest[_requester]].finalResult;
   }

   function getCurrentComputationId(address _requester) public view returns (uint id) {
     id = currentRequest[_requester];
   }

   function getServiceNum() public view returns(uint _length) {
     _length = service.length;
   }

   function stringToUint(string s) internal pure returns (uint result) {
     bytes memory b = bytes(s);
     uint i;
     result = 0;
     for(i = 0; i < b.length; i++){
       uint c = uint(b[i]);
       if(c <= 57 && c>= 48){
         result = result * 10 + (c - 48);
       }
     }
   }

   function stringsEqual(string _a, string _b) internal pure returns (bool result) {
     bytes memory a = bytes(_a);
     bytes memory b = bytes(_b);
     if(a.length != b.length){
       result = false;
       return;
     }

     for(uint i = 0; i < a.length; i++){
       if(a[i]!=b[i]){
         result = false;
         return ;
       }
     }
     result = true;
     return result;
   }

   function rand(uint min, uint max) internal constant returns (uint256 random) {

     uint256 blockValue = uint256(block.blockhash(block.number - 1));
     random = uint256(uint256(blockValue) % (min + max));
     return random;
   }

}
