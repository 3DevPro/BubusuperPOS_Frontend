// Label maps shared between branch_home_screen.dart and
// branch_loan_review_tab.dart — public (unlike every other _xLabels map in
// this feature, which stays file-private) specifically because both files
// need them. Still plain file-level const maps, not real i18n — same
// convention as everywhere else in this app.

const collateralKindLabels = {
  'motorcycle': 'มอเตอร์ไซค์',
  'car': 'รถยนต์',
  'tractor': 'แทรกเตอร์',
  'land_title': 'โฉนดที่ดิน',
};

const loanStageLabels = {
  'submitted': 'ยื่นคำขอ',
  'doc_review': 'ตรวจเอกสาร',
  'collateral_check': 'ตรวจหลักประกัน',
  'under_review': 'พิจารณาอนุมัติ',
  'approved': 'อนุมัติแล้ว',
  'disbursed': 'รับเงินแล้ว',
  'rejected': 'ไม่อนุมัติ',
};
