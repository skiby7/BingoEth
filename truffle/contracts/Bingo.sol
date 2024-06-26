// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
pragma experimental ABIEncoderV2; // Needed to use bytes32[][] as function parameter
contract Bingo {
/**************************************************************************** */
/**           Struct containing all the info for a game                      **/
/**************************************************************************** */

    struct Info {
        address creator;
        address[] joiners;
        uint maxJoiners;
        uint totalJoiners;
        uint ethBalance;
        uint betAmount;
        bytes32 creatorMerkleRoot;
        mapping(address => bytes32) joinerMerkleRoots; // Updated to a mapping
        uint8[] numbersExtracted;
        uint weiUsed;
        uint accusationTime;
        address accuser;
    }
    enum WinningReasons {
        BINGO,
        CREATOR_STALLED
    }

/************************************************ */
/**            Global variables                  **/
/************************************************ */
    int256 public lastGameId = 0; // Game ID counter
    mapping(int256 => Info) public gameList; // Mapping of game ID to game info
    int256[] public elencoGiochiDisponibili;    // List of available game IDs
    uint8[][] winningCombinations;


/***************************************** */
/**            Events                     **/
/***************************************** */

    event GameCreated(int256 indexed _gameId, uint256 _maxJoiners, uint256 _totalJoiners); //  Event to log game creation
    event Log(string message);
    //TODO: implementa piu persone
    event GameJoined(
        int256 indexed _gameId,
        address _creator,
        address _joiner,
        uint256 _maxjoiners,
        uint256 _totalJoiners,
        uint256 _ethAmount
    );
    event Checked(int256 indexed _gameId,bool _value);
    event GetInfo(
        int256 indexed _gameId,
        uint256 _maxjoiners,
        uint256 _totalJoiners,
        uint256 _ethAmount,
        bool _found
    );
    event Checkvalue(
        int256 indexed _gameId,
        address _address,
        uint256 _row,
        uint256 _col
    );
    event GameStarted(int256 indexed _gameId);

    event NumberExtracted(int256 _gameId, uint8 number,bool _endGame);

    event GameCancelled(uint256 indexed _gameId);
    //event to communicate the end of a game to all the joiners and the creator, loser is used if reason is that he cheated
    event NotBingo(int256 indexed _gameId, address player);

    event ConfirmRemovedAccuse(int256 _gameId);
    event GameEnded(
        int256 indexed _gameId,
        address _winner,
        uint256 _amountWonWei,
        uint256 _creatorRefundWei,
        bool _creatorWon,
        WinningReasons _reason
    );

    event ReceiveAccuse(
        int256 indexed _gameId,
        address _accuser
    );

    event AmountEthResponse(
        address _sender,
        uint256 _amount,
        uint256 indexed _gameId,
        uint256 _response
    );

    constructor() {
        winningCombinations.push([0, 1, 2, 3, 4]);    // ROW1
        winningCombinations.push([5, 6, 7, 8, 9]);    // ROW2
        winningCombinations.push([10, 11, 12, 13]);   // ROW3
        winningCombinations.push([14, 15, 16, 17, 18]); // ROW4
        winningCombinations.push([19, 20, 21, 22, 23]); // ROW5
        winningCombinations.push([0, 5, 10, 14, 19]); // COL1
        winningCombinations.push([1, 6, 11, 15, 20]); // COL2
        winningCombinations.push([2, 7, 16, 21]);     // COL3
        winningCombinations.push([3, 8, 12, 17, 22]); // COL4
        winningCombinations.push([4, 9, 13, 18, 23]); // COL5
        winningCombinations.push([0, 6, 17, 23]);     // DIAG1
        winningCombinations.push([4, 8, 15, 19]);     // DIAG2
     }

    /*********************************************** */
    /**               GETTERS                       **/
    /*********************************************** */
    function getGameId() private returns(int256) {
        return ++lastGameId;
    }

    function getInfo(int256 _gameId) private view returns (Info storage) {
        // Restituisce la struttura dati "info" associata al gameId specificato
        return gameList[_gameId];
    }

    function getInfoGame(int256 _gameId, uint seed) public {
        // Verifica se ci sono giochi disponibili
        require(_gameId >= 0, "Game ID must be greater than 0!");
        if(_gameId == 0) {
            int256 gameId = getRandomGame(seed);
            if (gameId <= 0)
                emit GetInfo(_gameId, 0, 0, 0, false);
            else
                emit GetInfo(gameId, gameList[gameId].maxJoiners, gameList[gameId].totalJoiners, gameList[gameId].betAmount, true);

        } else {
            if(findIndex(_gameId) > elencoGiochiDisponibili.length)
                emit GetInfo(_gameId, 0, 0, 0, false);
                // revert("Reverted because game is not available!");
            else
                emit GetInfo(_gameId, gameList[_gameId].maxJoiners, gameList[_gameId].totalJoiners, gameList[_gameId].betAmount, true);
        }
    }


    function getRandomNumber(uint256 _max, uint seed) private view returns (uint256) {
       require(_max > 0, "Max must be greater than 0");
        // Generate the random number
        uint randomHash = uint(keccak256(abi.encodePacked(seed, block.timestamp, block.difficulty, msg.sender)));
        // Ensure the result is within the desired range
        return (randomHash % _max);
    }

    function getRandomGame(uint seed) private view returns (int256 idGiocoCasuale) {
        // Verifica se ci sono giochi disponibili
        if (elencoGiochiDisponibili.length == 0) {
            return -1;
        }
        uint256 indiceCasuale = getRandomNumber(elencoGiochiDisponibili.length, seed);
        idGiocoCasuale = elencoGiochiDisponibili[indiceCasuale];// Ottiene l'ID del gioco corrispondente all'indice casuale
        //removeFromGiochiDisponibili(idGiocoCasuale);// Rimuove il gioco dalla lista degli ID disponibili se il massimo num di giocatori e' stato superato
        return idGiocoCasuale;
    }

    function getJoinerMerkleRoots(int256 _gameId) public view returns (bytes32[] memory) {
        uint256 joinerCount = gameList[_gameId].joiners.length;
        bytes32[] memory merkleRoots = new bytes32[](joinerCount);
        for (uint256 i = 0; i < joinerCount; i++) {
            address joiner = gameList[_gameId].joiners[i];
            merkleRoots[i] = gameList[_gameId].joinerMerkleRoots[joiner];
        }
        return merkleRoots;
    }

/************************************************ */
/**            Utility Functions                 **/
/************************************************ */
    function verifyMerkleProof(
        bytes32 _root,
        string memory _leaf,
        bytes32[] memory _proof,
        uint256 _index
    ) internal pure returns (bool) {
        bytes32 _hash = keccak256(abi.encodePacked(_leaf));
        // Starting from 2 to avoid resizing the proof array
        for (uint256 i = 2; i < _proof.length; i++) {
            if (_index % 2 == 0) {
                _hash = keccak256(abi.encodePacked(_hash, _proof[i]));
            } else {
                _hash = keccak256(abi.encodePacked(_proof[i], _hash));
            }
            _index /= 2;
        }
        return _hash == _root;
    }

    function removeGame(int256 _gameId) public returns (bool) {
        uint256 index = findIndex(_gameId);
        // Verifica se l'elemento è stato trovato e se il numero totale di partecipanti raggiunge il limite
        if (index < elencoGiochiDisponibili.length) {
                // Sostituisce l'elemento da rimuovere con l'ultimo elemento
                elencoGiochiDisponibili[index] = elencoGiochiDisponibili[elencoGiochiDisponibili.length - 1];
                // Rimuove l'ultimo elemento
                elencoGiochiDisponibili.pop();
                return true;
        }
        return false;
    }

    // Trova l'indice dell'elemento specificato nell'array elencoGiochiDisponibili
    function findIndex(int256 _gameId) private view returns (uint256) {
        for (uint256 i = 0; i < elencoGiochiDisponibili.length; i++) {
            if (elencoGiochiDisponibili[i] == _gameId) {
                return i;
            }
        }
        // Se l'elemento non è stato trovato, restituisci una posizione maggiore della lunghezza dell'array
        return elencoGiochiDisponibili.length+1;
    }

    function distributePrizetoAll(int256 _gameId) public {
        Info storage game = gameList[_gameId];
        uint256 betAmountPerPlayer = game.ethBalance /game.joiners.length;
        for (uint256 i = 0; i < game.joiners.length; i++) {
            address player = game.joiners[i];
            if (player != msg.sender) {
                payable(player).transfer(betAmountPerPlayer);
            }
        }
        if (game.creator != msg.sender) {
            payable(game.creator).transfer(betAmountPerPlayer);
        }
    }
    //returns true if the element is in the array
    function containsAddress(address[] memory array, address element) internal pure returns (bool) {
        uint256 length = array.length;
        for (uint256 i = 0; i < length; i++) {
            if (array[i] == element) {
                return true;
            }
        }
        return false;
    }

    //remove an address from an array
    function removeAddress(address[] memory array, address element) internal pure returns (address[] memory) {
        uint256 length = array.length;
        for (uint256 i = 0; i < length; i++) {
            if (array[i] == element) {
                array[i] = array[length - 1];
                assembly {
                    mstore(array, sub(length, 1))
                }
                return array;
            }
        }
        return array;
    }

    function removeFromGiochiDisponibili(int256 _gameId) public  returns (bool) {
        uint256 index = findIndex(_gameId);
        // Verifica se l'elemento è stato trovato e se il numero totale di partecipanti raggiunge il limite
        if (index < elencoGiochiDisponibili.length) {
                // Sostituisce l'elemento da rimuovere con l'ultimo elemento
                elencoGiochiDisponibili[index] = elencoGiochiDisponibili[elencoGiochiDisponibili.length - 1];
                // Rimuove l'ultimo elemento
                elencoGiochiDisponibili.pop();
                return true;

        }
        return false;
    }

    function containsSubarray(uint8[] memory subArray, uint[] memory array) public pure returns (bool) {
        for (uint8 i = 0; i < subArray.length; i++) {
            bool found = false;
            for (uint8 j = 0; j < array.length; j++) {
                if (subArray[i] == array[j]) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                return false;
            }
        }
        return true;
    }

    function isWinningCombination(uint[] memory combination) public view returns (bool) {
        for (uint8 i = 0; i < winningCombinations.length; i++) {
            if (containsSubarray(winningCombinations[i], combination))
                return true;
        }
        return false;
    }

    /**************************************************************** */
    /**       Functions to handle main logic of game                 **/
    /**************************************************************** */

    function createGame(uint _maxJoiners, uint _betAmount, bytes32 _cardMerkleRoot) public payable {
        require(_maxJoiners > 0, "Max joiners must be greater than 0");
        require(_betAmount <= 1000, "Max bet amount is 1000 ETH");
        require(msg.sender.balance/1 ether >= _betAmount, "Cannot bet more than you can afford!");
        require(msg.value == _betAmount*1 ether, "Please send exactly the amount you want to bet!");
        int256 gameId = getGameId();
        Info storage newGame = gameList[gameId];
        newGame.creator = msg.sender;
        newGame.joiners = new address[](0);
        newGame.maxJoiners = _maxJoiners;
        newGame.totalJoiners = 0;
        newGame.ethBalance = 0;
        newGame.betAmount = _betAmount;
        newGame.creatorMerkleRoot = _cardMerkleRoot;
        newGame.accusationTime = 0;
        newGame.accuser = address(0);

        // Initialize the creator's merkle root mapping
        newGame.joinerMerkleRoots[msg.sender] = 0;

        elencoGiochiDisponibili.push(gameId);

        newGame.ethBalance += _betAmount;

        emit GameCreated(
            gameId,
            newGame.maxJoiners,
            newGame.totalJoiners
        );
    }


    function joinGame(int256 _gameId, bytes32 _cardMerkleRoot) public payable {
        require(_gameId > 0, "Game ID must be greater than 0!");
        require(elencoGiochiDisponibili.length > 0, "No available games!");

        //check if the game is available and if the player is not the creator
        require(gameList[_gameId].totalJoiners < gameList[_gameId].maxJoiners, "Game already taken!");
        require(gameList[_gameId].creator != msg.sender, "You can't join a game created by yourself!");
        require(gameList[_gameId].creatorMerkleRoot != _cardMerkleRoot, "Invalid merkle root!");
        require(msg.sender.balance/1 ether >= gameList[_gameId].betAmount, "Cannot bet more than you can afford!");
        require(msg.value/1 ether == gameList[_gameId].betAmount, "Please send the correct bet amount!");

        for (uint i = 0; i < gameList[_gameId].joiners.length; i++) {
            require(
                gameList[_gameId]
                    .joinerMerkleRoots[gameList[_gameId]
                    .joiners[i]] != _cardMerkleRoot, "Invalid merkle root!");
        }
        //add the player to the game
        gameList[_gameId].joiners.push(msg.sender);
        gameList[_gameId].totalJoiners++;
        gameList[_gameId].ethBalance += gameList[_gameId].betAmount;
        gameList[_gameId].joinerMerkleRoots[msg.sender] = _cardMerkleRoot;

        emit GameJoined(
            _gameId,
            gameList[_gameId].creator,
            msg.sender,
            gameList[_gameId].maxJoiners,
            gameList[_gameId].totalJoiners,
            gameList[_gameId].ethBalance
        );
        if(gameList[_gameId].totalJoiners == gameList[_gameId].maxJoiners){
            removeFromGiochiDisponibili(_gameId);
            emit GameStarted(_gameId);
        }
    }

    function isExtracted(uint8[] memory numbersList, uint8 newNumber) internal pure returns(bool) {
        for (uint i = 0; i < numbersList.length; i++) {
            if (numbersList[i] == newNumber) return true;
        }
        return false;
    }

    function getNewNumber(int256 seed) internal view returns(uint8) {
        uint256 randomHash = uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, msg.sender, seed)));
        uint256 randomNumber = (randomHash % 75) + 1;
        return uint8(randomNumber);
    }

    function extractNumber(int256 _gameId, bool accused) public {
        uint startGas = gasleft();
        require(msg.sender == gameList[_gameId].creator, "Only the creator can extract a number!");
        require(gameList[_gameId].numbersExtracted.length <= 75, "All numbers have been extracted!");
        uint8 newNumber = getNewNumber(_gameId);
        int8 i = 1;
        while (isExtracted(gameList[_gameId].numbersExtracted, newNumber)) {
            newNumber = getNewNumber(_gameId+i);
            i++;
        }
        gameList[_gameId].numbersExtracted.push(newNumber);
        if(accused){
            gameList[_gameId].accusationTime = 0;
            gameList[_gameId].accuser = address(0);
            emit ConfirmRemovedAccuse(_gameId);

        }
        if(gameList[_gameId].numbersExtracted.length < 75){
            emit NumberExtracted(_gameId, newNumber,false);
        }else{
            emit GameEnded(_gameId, msg.sender, gameList[_gameId].ethBalance * 1 ether, 0, true, WinningReasons.BINGO);
            payable(msg.sender).transfer(gameList[_gameId].ethBalance * 1 ether);
        }
        gameList[_gameId].weiUsed += (startGas - gasleft()) * tx.gasprice;
    }

    function accuse (int256 _gameId) public {
        require(_gameId > 0, "Game id is negative!");
        require(gameList[_gameId].creator!=msg.sender, "Creator cannot accuse!");
        require(containsAddress(gameList[_gameId].joiners, msg.sender), "Player not in that game!");
        require(gameList[_gameId].accusationTime == 0, "Accusation already made!");
        gameList[_gameId].accusationTime = block.timestamp;
        gameList[_gameId].accuser = msg.sender;
        emit ReceiveAccuse(_gameId, msg.sender);
    }

    function checkAccuse(int256 _gameId) public {
        require(_gameId > 0, "Game id is negative!");
        require(gameList[_gameId].creator == msg.sender, "Only the Creator may accuse!");
        require(gameList[_gameId].accusationTime != 0, "Accusation not made");

        // Check if at least 5 seconds have passed since the accusation
        if (block.timestamp >= gameList[_gameId].accusationTime + 10) {
            // If more than 5 seconds have passed, handle end game logic

            // TODO: Pay all remaining players
            // Implement the logic to pay remaining players here

            emit GameEnded(_gameId, address(0), gameList[_gameId].ethBalance * 1 ether, 0, false, WinningReasons.CREATOR_STALLED);
            uint prize = (gameList[_gameId].ethBalance * 1 ether) / gameList[_gameId].totalJoiners;
            for (uint i = 0;i < gameList[_gameId].totalJoiners; i++) {
                payable(gameList[_gameId].joiners[i]).transfer(prize);
            }
        } else {
            emit Checked(_gameId, true);
        }
    }



    function bytes32ToString(bytes32 _bytes32) public pure returns (string memory) {
        uint8 i = 0;
        while (i < 32 && _bytes32[i] != 0) {
            i++;
        }
        bytes memory bytesArray = new bytes(i);
        for (i = 0; i < 32 && _bytes32[i] != 0; i++) {
            bytesArray[i] = _bytes32[i];
        }
        return string(bytesArray);
    }

    function stringToUint(string memory s) public pure returns (uint256) {
        bytes memory b = bytes(s);
        uint256 result = 0;
        for (uint256 i = 0; i < b.length; i++) {
            // Ensure the character is a digit
            require(b[i] >= 0x30 && b[i] <= 0x39, "Invalid character");
            result = result * 10 + (uint256(uint8(b[i])) - 48);
        }
        return result;
    }

    function submitCard(int256 _gameId, bytes32[][] memory _merkleProofs) public {
        require(_gameId > 0, "Game id is negative!");
        require(
            gameList[_gameId].creator == msg.sender || containsAddress(gameList[_gameId].joiners, msg.sender),
            "Player not in that game!"
        );
        bytes32 root = gameList[_gameId].creator == msg.sender
                       ? gameList[_gameId].creatorMerkleRoot
                       : gameList[_gameId].joinerMerkleRoots[msg.sender];
        bool isNumberExtracted = false;
        uint[] memory indexList = new uint[](_merkleProofs.length);
        uint index;
        for (uint8 i = 0; i < _merkleProofs.length; i++) {
            isNumberExtracted = false;
            for (uint8 j = 0; j < gameList[_gameId].numbersExtracted.length; j++) {
                if (gameList[_gameId].numbersExtracted[j] == stringToUint(bytes32ToString(_merkleProofs[i][0]))){
                    isNumberExtracted = true;
                    break;
                }
            }
            index = stringToUint(bytes32ToString(_merkleProofs[i][1]));
            indexList[i] = index;
            if (!isNumberExtracted || !verifyMerkleProof(root, bytes32ToString(_merkleProofs[i][0]), _merkleProofs[i], index)){
                emit NotBingo(_gameId, msg.sender);
                return;
            }
        }

        if (!isWinningCombination(indexList)) {
            emit NotBingo(_gameId, msg.sender);
            return;
        }

        if (msg.sender != gameList[_gameId].creator) {
            uint gameWeiAmount = gameList[_gameId].ethBalance * 1 ether;
            uint prize = gameWeiAmount - gameList[_gameId].weiUsed;

            emit GameEnded(_gameId, msg.sender, prize, gameList[_gameId].weiUsed, false, WinningReasons.BINGO);
            payable(msg.sender).transfer(prize);
            payable(gameList[_gameId].creator).transfer(gameList[_gameId].weiUsed);
        } else {
            emit GameEnded(_gameId, msg.sender, gameList[_gameId].ethBalance * 1 ether, 0, true, WinningReasons.BINGO);
            payable(msg.sender).transfer(gameList[_gameId].ethBalance * 1 ether);
        }

    }
}
