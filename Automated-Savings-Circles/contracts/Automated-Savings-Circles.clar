;; Automated Savings Circles - Traditional rotating savings groups with smart contract automation
;; Contract implements a decentralized tanda/chit fund system

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-CIRCLE-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-MEMBER (err u102))
(define-constant ERR-CIRCLE-FULL (err u103))
(define-constant ERR-CIRCLE-STARTED (err u104))
(define-constant ERR-INVALID-AMOUNT (err u105))
(define-constant ERR-PAYMENT-LATE (err u106))
(define-constant ERR-NOT-MEMBER (err u107))
(define-constant ERR-ALREADY-RECEIVED (err u108))
(define-constant ERR-CIRCLE-NOT-STARTED (err u109))
(define-constant ERR-INSUFFICIENT-FUNDS (err u110))

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant BLOCKS-PER-WEEK u1008) ;; Approximately 1 week in blocks
(define-constant MAX-MEMBERS u20)
(define-constant MIN-MEMBERS u3)

;; Data variables
(define-data-var circle-counter uint u0)
(define-data-var platform-fee-rate uint u250) ;; 2.5% in basis points

;; Circle status enum
(define-constant STATUS-FORMING u0)
(define-constant STATUS-ACTIVE u1)
(define-constant STATUS-COMPLETED u2)
(define-constant STATUS-CANCELLED u3)

;; Data structures
(define-map circles
  { circle-id: uint }
  {
    creator: principal,
    weekly-amount: uint,
    max-members: uint,
    current-members: uint,
    status: uint,
    start-block: uint,
    current-round: uint,
    total-rounds: uint
  }
)

(define-map circle-members
  { circle-id: uint, member: principal }
  {
    joined-at: uint,
    has-received-payout: bool,
    missed-payments: uint,
    total-contributed: uint
  }
)

(define-map member-list
  { circle-id: uint, position: uint }
  { member: principal }
)

(define-map round-recipients
  { circle-id: uint, round: uint }
  { recipient: principal, amount: uint, block-height: uint }
)

(define-map weekly-contributions
  { circle-id: uint, member: principal, week: uint }
  { amount: uint, block-height: uint }
)

;; Read-only functions
(define-read-only (get-circle (circle-id uint))
  (map-get? circles { circle-id: circle-id })
)

(define-read-only (get-member-info (circle-id uint) (member principal))
  (map-get? circle-members { circle-id: circle-id, member: member })
)

(define-read-only (get-member-by-position (circle-id uint) (position uint))
  (map-get? member-list { circle-id: circle-id, position: position })
)

(define-read-only (get-round-recipient (circle-id uint) (round uint))
  (map-get? round-recipients { circle-id: circle-id, round: round })
)

(define-read-only (get-weekly-contribution (circle-id uint) (member principal) (week uint))
  (map-get? weekly-contributions { circle-id: circle-id, member: member, week: week })
)

(define-read-only (get-current-week (circle-id uint))
  (match (get-circle circle-id)
    circle-data 
      (if (is-eq (get status circle-data) STATUS-ACTIVE)
        (ok (/ (- block-height (get start-block circle-data)) BLOCKS-PER-WEEK))
        ERR-CIRCLE-NOT-STARTED)
    ERR-CIRCLE-NOT-FOUND
  )
)

(define-read-only (calculate-platform-fee (amount uint))
  (/ (* amount (var-get platform-fee-rate)) u10000)
)

;; Public functions
(define-public (create-circle (weekly-amount uint) (max-members uint))
  (let (
    (new-circle-id (+ (var-get circle-counter) u1))
  )
    (asserts! (> weekly-amount u0) ERR-INVALID-AMOUNT)
    (asserts! (and (>= max-members MIN-MEMBERS) (<= max-members MAX-MEMBERS)) ERR-INVALID-AMOUNT)
    
    (map-set circles
      { circle-id: new-circle-id }
      {
        creator: tx-sender,
        weekly-amount: weekly-amount,
        max-members: max-members,
        current-members: u0,
        status: STATUS-FORMING,
        start-block: u0,
        current-round: u0,
        total-rounds: max-members
      }
    )
    
    (var-set circle-counter new-circle-id)
    (ok new-circle-id)
  )
)

(define-public (join-circle (circle-id uint))
  (let (
    (circle-data (unwrap! (get-circle circle-id) ERR-CIRCLE-NOT-FOUND))
    (current-members (get current-members circle-data))
  )
    (asserts! (is-eq (get status circle-data) STATUS-FORMING) ERR-CIRCLE-STARTED)
    (asserts! (< current-members (get max-members circle-data)) ERR-CIRCLE-FULL)
    (asserts! (is-none (get-member-info circle-id tx-sender)) ERR-ALREADY-MEMBER)
    
    ;; Add member to circle
    (map-set circle-members
      { circle-id: circle-id, member: tx-sender }
      {
        joined-at: block-height,
        has-received-payout: false,
        missed-payments: u0,
        total-contributed: u0
      }
    )
    
    ;; Add to member list
    (map-set member-list
      { circle-id: circle-id, position: current-members }
      { member: tx-sender }
    )
    
    ;; Update circle member count
    (map-set circles
      { circle-id: circle-id }
      (merge circle-data { current-members: (+ current-members u1) })
    )
    
    (ok true)
  )
)

(define-public (start-circle (circle-id uint))
  (let (
    (circle-data (unwrap! (get-circle circle-id) ERR-CIRCLE-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender (get creator circle-data)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status circle-data) STATUS-FORMING) ERR-CIRCLE-STARTED)
    (asserts! (>= (get current-members circle-data) MIN-MEMBERS) ERR-INVALID-AMOUNT)
    
    (map-set circles
      { circle-id: circle-id }
      (merge circle-data {
        status: STATUS-ACTIVE,
        start-block: block-height,
        current-round: u1
      })
    )
    
    (ok true)
  )
)

(define-public (contribute (circle-id uint))
  (let (
    (circle-data (unwrap! (get-circle circle-id) ERR-CIRCLE-NOT-FOUND))
    (member-data (unwrap! (get-member-info circle-id tx-sender) ERR-NOT-MEMBER))
    (current-week (unwrap! (get-current-week circle-id) ERR-CIRCLE-NOT-STARTED))
    (weekly-amount (get weekly-amount circle-data))
  )
    (asserts! (is-eq (get status circle-data) STATUS-ACTIVE) ERR-CIRCLE-NOT-STARTED)
    (asserts! (is-none (get-weekly-contribution circle-id tx-sender current-week)) ERR-ALREADY-RECEIVED)
    
    ;; Transfer STX to contract
    (try! (stx-transfer? weekly-amount tx-sender (as-contract tx-sender)))
    
    ;; Record contribution
    (map-set weekly-contributions
      { circle-id: circle-id, member: tx-sender, week: current-week }
      { amount: weekly-amount, block-height: block-height }
    )
    
    ;; Update member total contribution
    (map-set circle-members
      { circle-id: circle-id, member: tx-sender }
      (merge member-data {
        total-contributed: (+ (get total-contributed member-data) weekly-amount)
      })
    )
    
    (ok true)
  )
)

(define-public (distribute-payout (circle-id uint))
  (let (
    (circle-data (unwrap! (get-circle circle-id) ERR-CIRCLE-NOT-FOUND))
    (current-round (get current-round circle-data))
    (recipient-position (- current-round u1))
    (recipient-data (unwrap! (get-member-by-position circle-id recipient-position) ERR-NOT-MEMBER))
    (recipient (get member recipient-data))
    (total-amount (* (get weekly-amount circle-data) (get current-members circle-data)))
    (platform-fee (calculate-platform-fee total-amount))
    (payout-amount (- total-amount platform-fee))
  )
    (asserts! (is-eq (get status circle-data) STATUS-ACTIVE) ERR-CIRCLE-NOT-STARTED)
    (asserts! (is-none (get-round-recipient circle-id current-round)) ERR-ALREADY-RECEIVED)
    
    ;; Verify recipient hasn't received payout before
    (let ((member-info (unwrap! (get-member-info circle-id recipient) ERR-NOT-MEMBER)))
      (asserts! (not (get has-received-payout member-info)) ERR-ALREADY-RECEIVED)
      
      ;; Transfer payout to recipient
      (try! (as-contract (stx-transfer? payout-amount tx-sender recipient)))
      
      ;; Transfer platform fee to contract owner
      (try! (as-contract (stx-transfer? platform-fee tx-sender CONTRACT-OWNER)))
      
      ;; Record payout
      (map-set round-recipients
        { circle-id: circle-id, round: current-round }
        { recipient: recipient, amount: payout-amount, block-height: block-height }
      )
      
      ;; Mark member as received
      (map-set circle-members
        { circle-id: circle-id, member: recipient }
        (merge member-info { has-received-payout: true })
      )
      
      ;; Update circle round or complete
      (if (>= current-round (get total-rounds circle-data))
        (map-set circles
          { circle-id: circle-id }
          (merge circle-data { status: STATUS-COMPLETED })
        )
        (map-set circles
          { circle-id: circle-id }
          (merge circle-data { current-round: (+ current-round u1) })
        )
      )
      
      (ok payout-amount)
    )
  )
)

;; Admin functions
(define-public (update-platform-fee (new-fee-rate uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-fee-rate u1000) ERR-INVALID-AMOUNT) ;; Max 10%
    (var-set platform-fee-rate new-fee-rate)
    (ok true)
  )
)

(define-public (emergency-cancel-circle (circle-id uint))
  (let (
    (circle-data (unwrap! (get-circle circle-id) ERR-CIRCLE-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (not (is-eq (get status circle-data) STATUS-COMPLETED)) ERR-CIRCLE-NOT-FOUND)
    
    (map-set circles
      { circle-id: circle-id }
      (merge circle-data { status: STATUS-CANCELLED })
    )
    
    (ok true)
  )
)