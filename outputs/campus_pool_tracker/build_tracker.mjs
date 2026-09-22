import fs from 'node:fs/promises';
import { Workbook, SpreadsheetFile } from '@oai/artifact-tool';

const outDir = 'C:/TY_First_sem/EDI/campus_pool/outputs/campus_pool_tracker';
const wb = Workbook.create();
const dash = wb.worksheets.add('Dashboard');
const plan = wb.worksheets.add('Project Plan');
const risks = wb.worksheets.add('Risks & Decisions');
const guide = wb.worksheets.add('How To Use');
const navy = '#153B5B', blue = '#1F6E8C', teal = '#2C8C99', light = '#EAF3F6', pale = '#F7FAFC', amber = '#F4B942', red = '#C94C4C', green = '#3C8D5A', ink = '#1F2937', gray = '#64748B';

function title(sheet, text, subtitle, endCol) {
  sheet.getRange(`A1:${endCol}1`).merge(); sheet.getRange('A1').values = [[text]];
  sheet.getRange(`A2:${endCol}2`).merge(); sheet.getRange('A2').values = [[subtitle]];
  sheet.getRange(`A1:${endCol}1`).format = { fill: navy, font: { bold: true, color: '#FFFFFF', size: 18 }, horizontalAlignment: 'left', verticalAlignment: 'center' };
  sheet.getRange(`A2:${endCol}2`).format = { fill: navy, font: { color: '#DCEAF2', italic: true, size: 10 }, horizontalAlignment: 'left', verticalAlignment: 'center' };
  sheet.getRange('A1').format.rowHeight = 30; sheet.getRange('A2').format.rowHeight = 22;
}
function head(sheet, range) { sheet.getRange(range).format = { fill: blue, font: { bold: true, color: '#FFFFFF' }, horizontalAlignment: 'center', verticalAlignment: 'center', wrapText: true }; }

// PROJECT PLAN
title(plan, 'Campus Pool — Implementation Tracker', 'Update Status, % Complete, Owner, and dates weekly. Filter by phase, owner, or priority.', 'N');
const headers = ['ID','Phase','Feature / Workstream','Task','Priority','Owner','Planned Start','Target End','Status','% Complete','Dependency','Acceptance Criteria','Next Action','Notes'];
plan.getRange('A4:N4').values = [headers]; head(plan, 'A4:N4'); plan.getRange('A4:N4').format.rowHeight = 34;
const rows = [
['P0-01','0 — Foundation','Scope','Confirm MVP: ride offer, search, booking, auto groups, profile','Critical','Product owner','','','Not Started',0,'','Signed MVP scope and exclusions','Hold 45-minute scope review','No payments or live location in MVP'],
['P0-02','0 — Foundation','Scope','Define release success metrics and beta cohort size','High','Product owner','','','Not Started',0,'P0-01','Metrics documented: activation, completed rides, booking acceptance, incident rate','Set target values',''],
['P0-03','0 — Foundation','Architecture','Choose one authentication authority: Express JWT or Firebase Auth','Critical','Tech lead','','','Not Started',0,'P0-01','Decision recorded; duplicate auth removed or intentionally integrated','Review current Firebase/JWT overlap','Current Flutter login uses backend JWT'],
['P0-04','0 — Foundation','Environment','Create dev, staging, production environment matrix and secrets checklist','Critical','Backend owner','','','Not Started',0,'P0-03','No credentials committed; each environment has documented variables','Create .env templates and secret store',''],
['P0-05','0 — Foundation','Database','Apply Prisma schema to Neon development database','Critical','Backend owner','','','Not Started',0,'P0-04','Prisma generate and migration/push complete; tables verified','Run schema deployment','Auto-group tables are pending deployment'],
['P0-06','0 — Foundation','Design','Review all screens against MVP user flows and create missing-screen list','High','Designer','','','Not Started',0,'P0-01','Approved wireframes for every MVP screen/state','Inventory UI states',''],
['P0-07','0 — Foundation','Quality','Set up task board, defect severity rules, and weekly demo cadence','Medium','Project manager','','','Not Started',0,'P0-01','Team can report, triage, and close work consistently','Create board and cadence','This workbook can be the master project tracker'],
['P1-01','1 — Core Ride Flow','API client','Move API base URL to build-time/environment configuration','Critical','Flutter owner','','','Not Started',0,'P0-04','Android emulator, device, web, and release URLs work without source edits','Introduce config class','Hard-coded LAN IP currently exists'],
['P1-02','1 — Core Ride Flow','Models','Create Ride, Booking, Review DTOs with robust JSON parsing','Critical','Flutter owner','','','Not Started',0,'P1-01','Models cover all API fields and null/error cases','Add model files and unit tests',''],
['P1-03','1 — Core Ride Flow','Services','Implement RideService: search, detail, offer, my rides, status, cancel','Critical','Flutter owner','','','Not Started',0,'P1-02','All /api/rides endpoints reachable through typed methods','Add service methods',''],
['P1-04','1 — Core Ride Flow','Services','Implement BookingService: request, list, driver requests, respond, cancel','Critical','Flutter owner','','','Not Started',0,'P1-02','All /api/bookings endpoints reachable through typed methods','Add service methods',''],
['P1-05','1 — Core Ride Flow','UI','Build Find Rides screen with origin, destination, date, seat, vehicle filters','Critical','Flutter owner','','','Not Started',0,'P1-03','Search returns live API results with loading, empty, and error states','Implement screen',''],
['P1-06','1 — Core Ride Flow','UI','Build Ride Details screen and booking request form','Critical','Flutter owner','','','Not Started',0,'P1-04,P1-05','Passenger can inspect ride then submit a valid request','Implement detail and form',''],
['P1-07','1 — Core Ride Flow','UI','Build Offer Ride form with capacity, route, time, vehicle, notes','Critical','Flutter owner','','','Not Started',0,'P1-03','Driver can create a validated ride and see it in My Rides','Implement form',''],
['P1-08','1 — Core Ride Flow','UI','Build My Rides with driver and passenger views','Critical','Flutter owner','','','Not Started',0,'P1-03,P1-04','User sees live offered rides and requested/accepted bookings','Implement list states',''],
['P1-09','1 — Core Ride Flow','UI','Build driver booking-request queue with accept/reject confirmation','Critical','Flutter owner','','','Not Started',0,'P1-08','Driver response updates seat count and passenger status visibly','Implement queue',''],
['P1-10','1 — Core Ride Flow','UI','Connect dashboard cards, active ride, nearby rides to real API data','Critical','Flutter owner','','','Not Started',0,'P1-05,P1-08','No hard-coded rides or fixed active-ride flag remain','Replace dashboard mocks',''],
['P1-11','1 — Core Ride Flow','UX','Add cancellation and status-change confirmation/error flows','High','Flutter owner','','','Not Started',0,'P1-08','Users cannot accidentally cancel; failures have recovery action','Add dialogs and messages',''],
['P1-12','1 — Core Ride Flow','Backend','Verify capacity and double-booking behavior under concurrent requests','Critical','Backend owner','','','Not Started',0,'P0-05','No accepted booking exceeds available seats or duplicates passenger','Add transaction/integration tests',''],
['P2-01','2 — Navigation & Account','Navigation','Replace bottom-nav state toggle with routes for Home, Rides, Offer, Alerts, Profile','High','Flutter owner','','','Not Started',0,'P1-05,P1-07','Every tab opens a usable destination and preserves expected state','Wire navigation shell',''],
['P2-02','2 — Navigation & Account','Profile','Build profile view and edit profile form','High','Flutter owner','','','Not Started',0,'P0-03','Profile reads and updates /api/users/profile with validation','Implement profile UI',''],
['P2-03','2 — Navigation & Account','Vehicle','Build vehicle settings form for drivers','Medium','Flutter owner','','','Not Started',0,'P2-02','Vehicle API updates and role restrictions are clear','Implement vehicle UI',''],
['P2-04','2 — Navigation & Account','Session','Handle expired token, 401 errors, logout and login return path','Critical','Flutter owner','','','Not Started',0,'P0-03','Expired user is safely returned to login without stale data','Add auth interceptor/handling',''],
['P2-05','2 — Navigation & Account','Reviews','Build post-ride review and user review history screens','Medium','Flutter owner','','','Not Started',0,'P1-08','Eligible users can submit one 1–5 star review per ride','Implement review UI',''],
['P2-06','2 — Navigation & Account','Alerts','Define MVP alert model; build an in-app activity/booking update screen','Medium','Product + Flutter','','','Not Started',0,'P1-09','User can see meaningful booking/group updates','Choose local vs push MVP',''],
['P3-01','3 — Auto Groups','Backend','Run schema deployment and endpoint smoke tests for Auto Groups','High','Backend owner','','','Not Started',0,'P0-05','Create, join, confirm, leave, and permissions verified','Exercise endpoints with test users',''],
['P3-02','3 — Auto Groups','UX','Test matching window, group readiness, leave/rejoin behavior with 4 users','High','QA owner','','','Not Started',0,'P3-01','Expected group state across normal and edge cases documented','Create test scenarios',''],
['P3-03','3 — Auto Groups','UI','Add empty, error, refresh and confirmation states to Auto Groups','Medium','Flutter owner','','','Not Started',0,'P3-01','Screen communicates that fare/payment are not handled','Polish states',''],
['P4-01','4 — Safety & Security','Safety','Define community rules, reporting flow, blocked-user policy, and emergency guidance','Critical','Product owner','','','Not Started',0,'P0-01','Safety policy and in-app reporting path approved','Draft policy and escalation owner',''],
['P4-02','4 — Safety & Security','Backend','Add input validation and consistent error responses for every endpoint','Critical','Backend owner','','','Not Started',0,'P0-05','Malformed requests return safe, actionable 4xx errors','Audit controllers',''],
['P4-03','4 — Safety & Security','Backend','Restrict CORS, configure Helmet, and add rate limits to auth endpoints','Critical','Backend owner','','','Not Started',0,'P0-04','Production origin allow-list and abuse protection are verified','Add middleware/config',''],
['P4-04','4 — Safety & Security','Privacy','Minimize exposed phone/contact data and document retention/deletion policy','High','Product + Backend','','','Not Started',0,'P4-01','Only necessary personal data is shown to authorized users','Review response DTOs',''],
['P4-05','4 — Safety & Security','Authorization','Audit role and ownership checks for rides, bookings, reviews, profiles, groups','Critical','Backend owner','','','Not Started',0,'P4-02','Cross-user access attempts are denied in integration tests','Write authorization test matrix',''],
['P5-01','5 — Testing','Backend tests','Add test database config, seed helpers, and API integration test runner','Critical','Backend owner','','','Not Started',0,'P0-05','Tests run isolated from production database','Set up test environment',''],
['P5-02','5 — Testing','Backend tests','Cover auth, rides, bookings, reviews, auto-groups, and authorization failures','Critical','Backend owner','','','Not Started',0,'P5-01','Core endpoints have happy-path and failure coverage','Implement suites',''],
['P5-03','5 — Testing','Flutter tests','Test services/models including HTTP failures, token behavior, and JSON parsing','High','Flutter owner','','','Not Started',0,'P1-04','Core client logic is deterministic and covered','Add unit tests',''],
['P5-04','5 — Testing','Flutter tests','Add widget tests for auth, forms, empty/loading/error states, navigation','High','Flutter owner','','','Not Started',0,'P2-01','Critical screens render and validate inputs predictably','Add widget tests',''],
['P5-05','5 — Testing','Manual QA','Create device/browser test matrix and execute regression checklist','High','QA owner','','','Not Started',0,'P5-02,P5-04','Supported platforms and major flows pass regression','Draft checklist',''],
['P5-06','5 — Testing','Beta','Run controlled student beta; log feedback, incidents, and funnel metrics','High','Product owner','','','Not Started',0,'P5-05,P4-01','Beta exit criteria met without unresolved critical defects','Recruit pilot users',''],
['P6-01','6 — Release','Deployment','Deploy API and database migration to staging, then production','Critical','Backend owner','','','Not Started',0,'P5-02,P4-03','Health checks, environment variables, rollback steps verified','Create deployment runbook',''],
['P6-02','6 — Release','Monitoring','Add error logging, uptime checks, and basic metrics dashboard','High','Backend owner','','','Not Started',0,'P6-01','Team is alerted to API failure and can investigate errors','Choose monitoring stack',''],
['P6-03','6 — Release','Mobile release','Configure Android signing, package identifiers, icons, privacy policy links','High','Flutter owner','','','Not Started',0,'P5-05,P4-04','Release build installs and meets store/college distribution requirements','Prepare release config',''],
['P6-04','6 — Release','Documentation','Update README: setup, environment, commands, architecture, test instructions','Medium','Tech lead','','','Not Started',0,'P6-01','New contributor can run app/backend from clean checkout','Write docs',''],
['P6-05','6 — Release','Go-live','Run launch checklist, verify analytics, publish support contact, monitor first week','Critical','Project manager','','','Not Started',0,'P6-01,P6-02,P6-03','Launch owner signs off; critical incident route is staffed','Schedule go/no-go review',''],
];
plan.getRange(`A5:N${4 + rows.length}`).values = rows;
plan.getRange(`G5:H${4 + rows.length}`).format.numberFormat = 'yyyy-mm-dd';
plan.getRange(`J5:J${4 + rows.length}`).format.numberFormat = '0%';
plan.getRange(`A4:N${4 + rows.length}`).format.wrapText = true;
plan.getRange(`A4:N${4 + rows.length}`).format.verticalAlignment = 'top';
plan.getRange(`A4:N${4 + rows.length}`).format.borders = { preset: 'insideHorizontal', style: 'thin', color: '#DCE3E8' };
plan.getRange(`I5:I${4 + rows.length}`).dataValidation = { rule: { type: 'list', values: ['Not Started','In Progress','Blocked','In Review','Done'] } };
plan.getRange(`E5:E${4 + rows.length}`).dataValidation = { rule: { type: 'list', values: ['Critical','High','Medium','Low'] } };
plan.getRange(`J5:J${4 + rows.length}`).dataValidation = { rule: { type: 'decimal', operator: 'between', formula1: 0, formula2: 1 } };
plan.getRange(`I5:I${4 + rows.length}`).conditionalFormats.add('containsText', { text: 'Done', format: { fill: '#DFF3E6', font: { color: '#1B6B3A', bold: true } } });
plan.getRange(`I5:I${4 + rows.length}`).conditionalFormats.add('containsText', { text: 'Blocked', format: { fill: '#FBE3E3', font: { color: '#9B1C1C', bold: true } } });
plan.getRange(`I5:I${4 + rows.length}`).conditionalFormats.add('containsText', { text: 'In Progress', format: { fill: '#FFF2CC', font: { color: '#8A5A00', bold: true } } });
plan.getRange(`A4:N${4 + rows.length}`).format.autofitColumns();
const widths = [11,18,20,36,10,16,13,13,14,12,18,42,32,30]; widths.forEach((w,i)=>plan.getRangeByIndexes(0,i,1,1).format.columnWidth=w);
plan.getRange(`A5:N${4 + rows.length}`).format.rowHeight = 42; plan.freezePanes.freezeRows(4); plan.showGridLines = false;
plan.tables.add(`A4:N${4 + rows.length}`, true, 'ProjectTasks');

// DASHBOARD
title(dash, 'Campus Pool — Delivery Dashboard', 'Live summary driven by the Project Plan sheet. Update task rows there; this page refreshes automatically.', 'H'); dash.showGridLines = false;
dash.getRange('A4:B4').merge(); dash.getRange('C4:D4').merge(); dash.getRange('E4:F4').merge(); dash.getRange('G4:H4').merge();
dash.getRange('A4').values = [['Total Tasks']]; dash.getRange('C4').values = [['Complete']]; dash.getRange('E4').values = [['In Progress']]; dash.getRange('G4').values = [['Blocked']];
dash.getRange('A5:B6').merge(); dash.getRange('C5:D6').merge(); dash.getRange('E5:F6').merge(); dash.getRange('G5:H6').merge();
dash.getRange('A5').formulas = [[`=COUNTA('Project Plan'!A5:A${4 + rows.length})`]];
dash.getRange('C5').formulas = [[`=COUNTIF('Project Plan'!I5:I${4 + rows.length},"Done")`]];
dash.getRange('E5').formulas = [[`=COUNTIF('Project Plan'!I5:I${4 + rows.length},"In Progress")`]];
dash.getRange('G5').formulas = [[`=COUNTIF('Project Plan'!I5:I${4 + rows.length},"Blocked")`]];
for (const r of ['A4:B4','C4:D4','E4:F4','G4:H4']) dash.getRange(r).format = { fill: blue, font: { bold: true, color: '#FFFFFF' }, horizontalAlignment: 'center' };
for (const r of ['A5:B6','C5:D6','E5:F6','G5:H6']) dash.getRange(r).format = { fill: light, font: { bold: true, color: navy, size: 22 }, horizontalAlignment: 'center', verticalAlignment: 'center', borders: { preset: 'outside', style: 'thin', color: '#B9D4DE' } };
dash.getRange('A9:H9').merge(); dash.getRange('A9').values = [['Progress by Phase']]; dash.getRange('A9:H9').format = { fill: teal, font: { bold: true, color: '#FFFFFF', size: 12 } };
dash.getRange('A10:D10').values = [['Phase','Tasks','Done','Completion']]; head(dash,'A10:D10');
const phases = ['0 — Foundation','1 — Core Ride Flow','2 — Navigation & Account','3 — Auto Groups','4 — Safety & Security','5 — Testing','6 — Release'];
dash.getRange('A11:A17').values = phases.map(x=>[x]);
for(let row=11; row<=17; row++) { dash.getRange(`B${row}`).formulas = [[`=COUNTIF('Project Plan'!B$5:B$${4 + rows.length},A${row})`]]; dash.getRange(`C${row}`).formulas = [[`=COUNTIFS('Project Plan'!B$5:B$${4 + rows.length},A${row},'Project Plan'!I$5:I$${4 + rows.length},"Done")`]]; dash.getRange(`D${row}`).formulas = [[`=IFERROR(C${row}/B${row},0)`]]; }
dash.getRange('D11:D17').format.numberFormat = '0%'; dash.getRange('A10:D17').format.borders = { preset: 'all', style: 'thin', color: '#DCE3E8' }; dash.getRange('D11:D17').conditionalFormats.add('dataBar',{color: teal,gradient:true});
dash.getRange('F10:H10').merge(); dash.getRange('F10').values = [['Immediate Focus']]; head(dash,'F10:H10');
dash.getRange('F11:H17').merge(); dash.getRange('F11').values = [['Start with the Core Ride Flow: configure API URLs, add typed Ride/Booking services, then deliver Find Rides, Offer Ride, Details, and Booking Requests.\n\nGate every phase with its acceptance criteria in Project Plan.\n\nCritical decisions: single auth approach, environment/secrets, safety policy, and test database.']]; dash.getRange('F11:H17').format = { fill: pale, font: { color: ink, size: 11 }, wrapText: true, verticalAlignment: 'top', borders: { preset: 'outside', style: 'thin', color: '#DCE3E8' } };
dash.getRange('A20:H20').merge(); dash.getRange('A20').values = [['Weekly Update Checklist']]; dash.getRange('A20:H20').format = { fill: teal, font: { bold: true, color: '#FFFFFF' } };
dash.getRange('A21:H24').merge(); dash.getRange('A21').values = [['1. Update Status, % Complete, Owner, planned dates, and Next Action for every active task.\n2. Mark blockers and record the decision required in Risks & Decisions.\n3. Filter Project Plan for Critical / High tasks due in the next two weeks.\n4. Use the dashboard during the weekly delivery review.']]; dash.getRange('A21:H24').format = { fill: pale, font: { color: ink }, wrapText: true, verticalAlignment: 'top' };
['A','B','C','D','E','F','G','H'].forEach(c=>dash.getRange(`${c}1`).format.columnWidth=16); dash.getRange('A1').format.rowHeight=30; dash.getRange('A2').format.rowHeight=22;

// RISKS
title(risks, 'Risks & Decisions Log', 'Use this sheet to surface delivery threats early and document choices that affect scope, architecture, or launch.', 'I'); risks.showGridLines=false;
const rh = ['ID','Type','Title','Description / Decision Needed','Impact','Likelihood','Owner','Status','Target Date']; risks.getRange('A4:I4').values=[rh]; head(risks,'A4:I4');
const riskRows = [
['R-01','Decision','Authentication source of truth','Choose Express JWT only, Firebase Auth only, or a documented integration. Current code initializes Firebase but signs in through Express.','High','High','Tech lead','Open',''],
['R-02','Risk','Device cannot reach backend','Hard-coded local/LAN base URL prevents repeatable testing and release builds.','High','High','Flutter owner','Open',''],
['R-03','Risk','Seat overbooking','Concurrent booking requests may exceed ride capacity without transaction-level protection.','High','Medium','Backend owner','Open',''],
['R-04','Decision','Safety operating model','Agree reporting escalation, emergency guidance, verification expectations, and contact-data exposure.','High','High','Product owner','Open',''],
['R-05','Risk','No automated regression coverage','Backend has no established integration test suite; critical booking permissions can regress.','High','Medium','QA owner','Open',''],
['R-06','Risk','Database schema not deployed','Auto Groups code cannot be used until Prisma schema reaches the development database.','High','Medium','Backend owner','Open',''],
];
risks.getRange(`A5:I${4+riskRows.length}`).values=riskRows; risks.getRange(`I5:I${4+riskRows.length}`).format.numberFormat='yyyy-mm-dd'; risks.getRange(`B5:B${4+riskRows.length}`).dataValidation={rule:{type:'list',values:['Risk','Decision','Issue','Assumption']}}; risks.getRange(`H5:H${4+riskRows.length}`).dataValidation={rule:{type:'list',values:['Open','Monitoring','Mitigating','Resolved','Accepted']}}; risks.getRange(`E5:F${4+riskRows.length}`).dataValidation={rule:{type:'list',values:['Low','Medium','High','Critical']}}; risks.getRange(`A4:I${4+riskRows.length}`).format.wrapText=true; risks.getRange(`A4:I${4+riskRows.length}`).format.borders={preset:'insideHorizontal',style:'thin',color:'#DCE3E8'}; risks.getRange(`A4:I${4+riskRows.length}`).format.autofitColumns(); [10,13,25,52,12,12,17,14,14].forEach((w,i)=>risks.getRangeByIndexes(0,i,1,1).format.columnWidth=w); risks.getRange(`A5:I${4+riskRows.length}`).format.rowHeight=46; risks.freezePanes.freezeRows(4); risks.tables.add(`A4:I${4+riskRows.length}`,true,'RisksLog');

// GUIDE
title(guide,'How To Use This Tracker','A lightweight operating guide for keeping project progress visible and credible.', 'G'); guide.showGridLines=false;
guide.getRange('A4:G4').merge(); guide.getRange('A4').values=[['Update cadence']]; head(guide,'A4:G4');
guide.getRange('A5:G8').merge(); guide.getRange('A5').values=[['Before the weekly review, task owners update the Project Plan. Use “In Progress” only when active work is underway; use “Blocked” when outside help or a decision is needed. Set % Complete conservatively and make Next Action specific enough to execute.']]; guide.getRange('A5:G8').format={fill:pale,font:{color:ink},wrapText:true,verticalAlignment:'top'};
guide.getRange('A10:G10').merge(); guide.getRange('A10').values=[['Status definitions']]; head(guide,'A10:G10');
guide.getRange('A11:C16').values=[['Status','Meaning','Rule'],['Not Started','No work begun','Keep % Complete at 0%'],['In Progress','Actively being worked','Name an owner and next action'],['Blocked','Cannot proceed','Add a log entry in Risks & Decisions'],['In Review','Awaiting QA/review/approval','Do not mark done until acceptance criteria pass'],['Done','Acceptance criteria met','Set % Complete to 100%']]; head(guide,'A11:C11'); guide.getRange('A11:C16').format.borders={preset:'all',style:'thin',color:'#DCE3E8'}; guide.getRange('A11:C16').format.wrapText=true;
guide.getRange('A18:G18').merge(); guide.getRange('A18').values=[['Recommended working order']]; head(guide,'A18:G18');
guide.getRange('A19:G23').merge(); guide.getRange('A19').values=[['Foundation → Core Ride Flow → Navigation & Account → Auto Groups validation → Safety & Security → Testing → Release.\n\nDo not move toward a public launch until P1 core flow, P4 safety/security controls, P5 regression testing, and P6 deployment checks are genuinely complete.']]; guide.getRange('A19:G23').format={fill:light,font:{color:ink,bold:true},wrapText:true,verticalAlignment:'top'};
[18,20,26,18,18,18,18].forEach((w,i)=>guide.getRangeByIndexes(0,i,1,1).format.columnWidth=w);

await fs.mkdir(outDir,{recursive:true});
const out=await SpreadsheetFile.exportXlsx(wb); await out.save(`${outDir}/campus_pool_implementation_tracker.xlsx`);
const checks = await wb.inspect({kind:'table',range:'Dashboard!A1:H24',include:'values,formulas',tableMaxRows:24,tableMaxCols:8});
console.log(checks.ndjson);
const errors=await wb.inspect({kind:'match',searchTerm:'#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A',options:{useRegex:true,maxResults:100},summary:'formula error scan'}); console.log(errors.ndjson);
for (const sheetName of ['Dashboard','Project Plan','Risks & Decisions','How To Use']) { const blob=await wb.render({sheetName,autoCrop:'all',scale:1,format:'png'}); await fs.writeFile(`${outDir}/${sheetName.replaceAll(' ','_')}.png`,new Uint8Array(await blob.arrayBuffer())); }
