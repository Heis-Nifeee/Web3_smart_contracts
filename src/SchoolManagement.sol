// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./IERC20.sol";

contract SchoolManagement {
    IERC20 token;
    address owner;
    address admin;

    uint256 public studentIdCounter;
    uint256 public staffIdCounter;

    modifier onlyOwner() {
        require(msg.sender == owner, "YOU'RE NOT THE OWNER");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "YOU'RE NOT AN ADMIN");
        _;
    }

    modifier validLevel(uint256 _level) {
        require(
            _level == 100 || _level == 200 || _level == 300 || _level == 400,
            "INVALID LEVEL. MUST BE 100, 200, 300, OR 400"
        );
        _;
    }

    modifier validAddress (address _address) {
        require(_address != address(0), "ADDRESS ZERO DETECTED");
        _;
    }

    modifier notStudent(address _address) {
        require(students[_address].studentAddress == address(0), "ADDRESS BELONGS TO A STUDENT");
        _;
    }

    modifier notStaff(address _address) {
        require(!staffs[_address].exists, "ADDRESS BELONGS TO A STAFF");
        _;
    }

    constructor(address _token, address _admin) validAddress(_token) validAddress(_admin) {
        token = IERC20(_token);
        owner = msg.sender;
        admin = _admin;

        studentIdCounter = 1;
        staffIdCounter = 1;
    }

    struct Student {
        address studentAddress;
        uint256 id;
        string name;
        uint256 age;
        uint256 level;
        bool hasPaid;
        uint256 paidAt;
    }

    struct Staff {
        address staffAddress;
        uint256 id;
        string name;
        string role;
        uint256 salary;
        uint256 lastPaid;
        bool exists;
        bool suspended;
    }

    mapping(address => Student) students;
    mapping(address => Staff) staffs;

    address[] allStudents;
    address[] allStaffs;

    mapping(uint256 => uint256) levelFees;

    event StudentEnrolled(address indexed student, string name, uint256 level, uint256 feePaid, uint256 timestamp);
    event StaffEmployed(address indexed staff, string name, string role, uint256 salary);
    event StaffPaid(address indexed staff, uint256 amount, uint256 timestamp);
    event StaffSuspended(address indexed staff, bool suspended);

    function setLevelFees() external onlyOwner() {
        levelFees[100] = 100 * 10**18;
        levelFees[200] = 200 * 10**18;
        levelFees[300] = 300 * 10**18;
        levelFees[400] = 400 * 10**18;
    }

    function enrollStudent(string memory _name, uint256 _age, uint256 _level, address _student) external onlyAdmin() validLevel(_level) validAddress(_student) notStaff(_student) {
        require(students[_student].level == 0, "STUDENT ALREADY REGISTERED");
        require(_student != owner, "YOU'RE THE SCHOOL OWNER");
        require(_student != admin, "YOU'RE THE SCHOOL ADMIN");

        uint256 fee = levelFees[_level];
        require(fee > 0, "INSUFFIENT LEVEL FEE");
        require(token.transferFrom(_student, address(this), fee), "FEE TRANSFER FAILED");

        uint256 studentId = studentIdCounter;

        students[_student] = Student({
            studentAddress: _student,
            id: studentId,
            name: _name,
            age: _age,
            level: _level,
            hasPaid: true,
            paidAt: block.timestamp
        });

        allStudents.push(_student);

        studentIdCounter++;

        emit StudentEnrolled(_student, _name, _level, fee, block.timestamp);
    }

    function getAllStudentsWithDetails() external view returns (Student[] memory) {
        uint256 count = allStudents.length;
        Student[] memory list = new Student[](count);

        for (uint256 i = 0; i < count; i++) {
            list[i] = students[allStudents[i]];
        }

        return list;
    }

    function employStaff(address _staff, string memory _name, string memory _role, uint256 _salary) external onlyOwner() validAddress(_staff) notStudent(_staff) {
        require(!staffs[_staff].exists, "STAFF ALREADY EMPLOYED");
        require(_salary > 0, "SALARY MUST BE GREATER THAN 0");

        uint256 staffId = staffIdCounter;

        staffs[_staff] = Staff({
            staffAddress: _staff,
            id: staffId,
            name: _name,
            salary: _salary,
            role: _role,
            lastPaid: 0,
            exists: true,
            suspended: false
        });

        allStaffs.push(_staff);

        staffIdCounter++;

        emit StaffEmployed(_staff, _name, _role, _salary);
    }

    function payStaff(address _staff) external onlyOwner() validAddress(_staff) notStudent(_staff) {
        require(_staff != owner, "YOU'RE THE SCHOOL OWNER");
        require(_staff != admin, "YOU'RE THE SCHOOL ADMIN");

        Staff storage st = staffs[_staff];

        require(st.exists, "STAFF NOT FOUND");
        require(!st.suspended, "STAFF IS SUSPENDED");
        require(st.salary > 0, "INVALID SALARY");
        require(token.transfer(_staff, st.salary), "PAYMENT FAILED");

        st.lastPaid = block.timestamp;

        emit StaffPaid(_staff, st.salary, block.timestamp);
    }

    function suspendStaff(address _staff, bool _suspend) external onlyOwner() validAddress(_staff) {
        require(staffs[_staff].exists, "STAFF NOT FOUND");
        
        staffs[_staff].suspended = _suspend;
        
        emit StaffSuspended(_staff, _suspend);
    }

    function getAllStaff() external view returns(address[] memory) {
        return allStaffs;
    }

    function contractTokenBalance() external view returns(uint256) {
        return token.balanceOf(address(this));
    }
}
