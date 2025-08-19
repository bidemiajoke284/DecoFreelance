;; DecoFreelance Job Posting Contract
;; Clarity v2
;; Manages creation, bidding, assignment, and status tracking of freelance jobs
;; Includes admin controls, pausing, job editing, cancellation, and detailed querying

(define-constant ERR-NOT-AUTHORIZED u100)
(define-constant ERR-INSUFFICIENT-DETAILS u101)
(define-constant ERR-JOB-NOT-FOUND u102)
(define-constant ERR-INVALID-STATUS u103)
(define-constant ERR-PAUSED u104)
(define-constant ERR-ZERO-ADDRESS u105)
(define-constant ERR-BID-TOO-LOW u106)
(define-constant ERR-BID-EXISTS u107)
(define-constant ERR-NOT-CLIENT u108)
(define-constant ERR-JOB-NOT-OPEN u109)
(define-constant ERR-INVALID-AMOUNT u110)
(define-constant ERR-DEADLINE-PASSED u111)
(define-constant ERR-EDIT-NOT-ALLOWED u112)
(define-constant ERR-CANCEL-NOT-ALLOWED u113)
(define-constant ERR-INVALID-JOB-ID u114)
(define-constant ERR-INVALID-STRING-LEN u115)
(define-constant ERR-INVALID-TIME u116)

;; Job status constants
(define-constant STATUS-OPEN "open")
(define-constant STATUS-BIDDING "bidding")
(define-constant STATUS-ASSIGNED "assigned")
(define-constant STATUS-IN-PROGRESS "in-progress")
(define-constant STATUS-COMPLETED "completed")
(define-constant STATUS-CANCELLED "cancelled")
(define-constant STATUS-DISPUTED "disputed")

;; Contract metadata
(define-constant CONTRACT-NAME "DecoFreelance Job Posting")
(define-constant MIN-BID-AMOUNT u100) ;; Minimum bid in micro-units (e.g., uSTX)
(define-constant MAX-DESCRIPTION-LEN u500) ;; Max length for job description
(define-constant MAX-TITLE-LEN u100) ;; Max length for job title

;; Admin and contract state
(define-data-var admin principal tx-sender)
(define-data-var paused bool false)
(define-data-var job-counter uint u0)

;; Maps
(define-map jobs uint 
  {
    client: principal,
    title: (string-utf8 100),
    description: (string-utf8 500),
    budget: uint,
    deadline: uint, ;; Block height
    bid-deadline: uint,
    status: (string-ascii 20),
    assigned-to: (optional principal),
    created-at: uint
  }
)

(define-map bids {job-id: uint, bidder: principal} 
  {
    amount: uint,
    proposed-time: uint, ;; Estimated completion time
    bid-at: uint
  }
)

(define-map job-bid-count uint uint) ;; Count of bids per job

;; Private helper: is-admin
(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

;; Private helper: ensure }}, not paused
(define-private (ensure-not-paused)
  (asserts! (not (var-get paused)) (err ERR-PAUSED))
)

;; Private helper: is-client
(define-private (is-client (job-id uint))
  (match (map-get? jobs job-id)
    job (is-eq tx-sender (get client job))
    false
  )
)

;; Private helper: get-current-block
(define-private (get-current-block)
  block-height
)

;; Transfer admin rights
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
    (asserts! (not (is-eq new-admin 'SP000000000000000000002Q6VF78)) (err ERR-ZERO-ADDRESS))
    (var-set admin new-admin)
    (ok true)
  )
)

;; Pause/unpause the contract
(define-public (set-paused (pause bool))
  (begin
    (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
    (var-set paused pause)
    (ok pause)
  )
)

;; Create a new job
(define-public (create-job (title (string-utf8 100)) (description (string-utf8 500)) (budget uint) (deadline uint) (bid-deadline uint))
  (begin
    (ensure-not-paused)
    (asserts! (> (len title) u0) (err ERR-INSUFFICIENT-DETAILS))
    (asserts! (<= (len title) MAX-TITLE-LEN) (err ERR-INVALID-STRING-LEN))
    (asserts! (> (len description) u0) (err ERR-INSUFFICIENT-DETAILS))
    (asserts! (<= (len description) MAX-DESCRIPTION-LEN) (err ERR-INVALID-STRING-LEN))
    (asserts! (>= budget MIN-BID-AMOUNT) (err ERR-INVALID-AMOUNT))
    (asserts! (> deadline (get-current-block)) (err ERR-DEADLINE-PASSED))
    (asserts! (> bid-deadline (get-current-block)) (err ERR-DEADLINE-PASSED))
    (asserts! (<= bid-deadline deadline) (err ERR-DEADLINE-PASSED))
    (let ((job-id (+ (var-get job-counter) u1)))
      (map-set jobs job-id 
        {
          client: tx-sender,
          title: title,
          description: description,
          budget: budget,
          deadline: deadline,
          bid-deadline: bid-deadline,
          status: STATUS-OPEN,
          assigned-to: none,
          created-at: (get-current-block)
        }
      )
      (var-set job-counter job-id)
      (map-set job-bid-count job-id u0)
      (ok job-id)
    )
  )
)

;; Place a bid on a job
(define-public (place-bid (job-id uint) (amount uint) (proposed-time uint))
  (begin
    (ensure-not-paused)
    (asserts! (> job-id u0) (err ERR-INVALID-JOB-ID))
    (asserts! (> proposed-time u0) (err ERR-INVALID-TIME))
    (match (map-get? jobs job-id)
      job 
        (begin
          (asserts! (is-eq (get status job) STATUS-OPEN) (err ERR-JOB-NOT-OPEN))
          (asserts! (<= (get-current-block) (get bid-deadline job)) (err ERR-DEADLINE-PASSED))
          (asserts! (>= amount MIN-BID-AMOUNT) (err ERR-BID-TOO-LOW))
          (asserts! (<= amount (get budget job)) (err ERR-BID-TOO-LOW))
          (asserts! (is-none (map-get? bids {job-id: job-id, bidder: tx-sender})) (err ERR-BID-EXISTS))
          (map-set bids {job-id: job-id, bidder: tx-sender} 
            {
              amount: amount,
              proposed-time: proposed-time,
              bid-at: (get-current-block)
            }
          )
          (let ((new-bid-count (+ u1 (default-to u0 (map-get? job-bid-count job-id)))))
            (map-set job-bid-count job-id new-bid-count)
            (if (> new-bid-count u0)
              (map-set jobs job-id (merge job {status: STATUS-BIDDING}))
              false
            )
          )
          (ok true)
        )
      (err ERR-JOB-NOT-FOUND)
    )
  )
)

;; Accept a bid and assign the job
(define-public (accept-bid (job-id uint) (bidder principal))
  (begin
    (ensure-not-paused)
    (asserts! (> job-id u0) (err ERR-INVALID-JOB-ID))
    (asserts! (is-client job-id) (err ERR-NOT-CLIENT))
    (match (map-get? jobs job-id)
      job 
        (begin
          (asserts! (or (is-eq (get status job) STATUS-OPEN) (is-eq (get status job) STATUS-BIDDING)) (err ERR-INVALID-STATUS))
          (match (map-get? bids {job-id: job-id, bidder: bidder})
            bid 
              (begin
                (map-set jobs job-id 
                  (merge job 
                    {
                      status: STATUS-ASSIGNED,
                      assigned-to: (some bidder)
                    }
                  )
                )
                (ok true)
              )
            (err ERR-JOB-NOT-FOUND)
          )
        )
      (err ERR-JOB-NOT-FOUND)
    )
  )
)

;; Start job progress (by assigned freelancer)
(define-public (start-progress (job-id uint))
  (begin
    (ensure-not-paused)
    (asserts! (> job-id u0) (err ERR-INVALID-JOB-ID))
    (match (map-get? jobs job-id)
      job 
        (begin
          (asserts! (is-eq (get status job) STATUS-ASSIGNED) (err ERR-INVALID-STATUS))
          (asserts! (is-eq tx-sender (unwrap! (get assigned-to job) (err ERR-NOT-AUTHORIZED))) (err ERR-NOT-AUTHORIZED))
          (map-set jobs job-id (merge job {status: STATUS-IN-PROGRESS}))
          (ok true)
        )
      (err ERR-JOB-NOT-FOUND)
    )
  )
)

;; Mark job as completed
(define-public (mark-completed (job-id uint))
  (begin
    (ensure-not-paused)
    (asserts! (> job-id u0) (err ERR-INVALID-JOB-ID))
    (match (map-get? jobs job-id)
      job 
        (begin
          (asserts! (is-eq (get status job) STATUS-IN-PROGRESS) (err ERR-INVALID-STATUS))
          (asserts! (or (is-client job-id) (is-eq tx-sender (unwrap! (get assigned-to job) (err ERR-NOT-AUTHORIZED)))) (err ERR-NOT-AUTHORIZED))
          (asserts! (<= (get-current-block) (get deadline job)) (err ERR-DEADLINE-PASSED))
          (map-set jobs job-id (merge job {status: STATUS-COMPLETED}))
          (ok true)
        )
      (err ERR-JOB-NOT-FOUND)
    )
  )
)

;; Cancel job (by client, if not assigned or in progress)
(define-public (cancel-job (job-id uint))
  (begin
    (ensure-not-paused)
    (asserts! (> job-id u0) (err ERR-INVALID-JOB-ID))
    (asserts! (is-client job-id) (err ERR-NOT-CLIENT))
    (match (map-get? jobs job-id)
      job 
        (begin
          (asserts! (or (is-eq (get status job) STATUS-OPEN) (is-eq (get status job) STATUS-BIDDING)) (err ERR-CANCEL-NOT-ALLOWED))
          (map-set jobs job-id (merge job {status: STATUS-CANCELLED}))
          (ok true)
        )
      (err ERR-JOB-NOT-FOUND)
    )
  )
)

;; Edit job details (by client, only if open)
(define-public (edit-job (job-id uint) (new-title (optional (string-utf8 100))) (new-description (optional (string-utf8 500))) (new-budget (optional uint)) (new-deadline (optional uint)) (new-bid-deadline (optional uint)))
  (begin
    (ensure-not-paused)
    (asserts! (> job-id u0) (err ERR-INVALID-JOB-ID))
    (asserts! (is-client job-id) (err ERR-NOT-CLIENT))
    (match (map-get? jobs job-id)
      job 
        (begin
          (asserts! (is-eq (get status job) STATUS-OPEN) (err ERR-EDIT-NOT-ALLOWED))
          (let (
            (title (default-to (get title job) new-title))
            (description (default-to (get description job) new-description))
            (budget (default-to (get budget job) new-budget))
            (deadline (default-to (get deadline job) new-deadline))
            (bid-deadline (default-to (get bid-deadline job) new-bid-deadline))
          )
            (asserts! (<= (len title) MAX-TITLE-LEN) (err ERR-INVALID-STRING-LEN))
            (asserts! (<= (len description) MAX-DESCRIPTION-LEN) (err ERR-INVALID-STRING-LEN))
            (asserts! (>= budget MIN-BID-AMOUNT) (err ERR-INVALID-AMOUNT))
            (asserts! (> deadline (get-current-block)) (err ERR-DEADLINE-PASSED))
            (asserts! (> bid-deadline (get-current-block)) (err ERR-DEADLINE-PASSED))
            (asserts! (<= bid-deadline deadline) (err ERR-DEADLINE-PASSED))
            (map-set jobs job-id 
              (merge job 
                {
                  title: title,
                  description: description,
                  budget: budget,
                  deadline: deadline,
                  bid-deadline: bid-deadline
                }
              )
            )
            (ok true)
          )
        )
      (err ERR-JOB-NOT-FOUND)
    )
  )
)

;; Withdraw bid (before assignment)
(define-public (withdraw-bid (job-id uint))
  (begin
    (ensure-not-paused)
    (asserts! (> job-id u0) (err ERR-INVALID-JOB-ID))
    (match (map-get? jobs job-id)
      job 
        (begin
          (asserts! (or (is-eq (get status job) STATUS-OPEN) (is-eq (get status job) STATUS-BIDDING)) (err ERR-INVALID-STATUS))
          (asserts! (is-some (map-get? bids {job-id: job-id, bidder: tx-sender})) (err ERR-JOB-NOT-FOUND))
          (map-delete bids {job-id: job-id, bidder: tx-sender})
          (let ((current-bid-count (default-to u0 (map-get? job-bid-count job-id))))
            (map-set job-bid-count job-id (- current-bid-count u1))
            (if (is-eq current-bid-count u1)
              (map-set jobs job-id (merge job {status: STATUS-OPEN}))
              false
            )
          )
          (ok true)
        )
      (err ERR-JOB-NOT-FOUND)
    )
  )
)

;; Mark job as disputed
(define-public (mark-disputed (job-id uint))
  (begin
    (ensure-not-paused)
    (asserts! (> job-id u0) (err ERR-INVALID-JOB-ID))
    (match (map-get? jobs job-id)
      job 
        (begin
          (asserts! (is-eq (get status job) STATUS-IN-PROGRESS) (err ERR-INVALID-STATUS))
          (asserts! (or (is-client job-id) (is-eq tx-sender (unwrap! (get assigned-to job) (err ERR-NOT-AUTHORIZED)))) (err ERR-NOT-AUTHORIZED))
          (map-set jobs job-id (merge job {status: STATUS-DISPUTED}))
          (ok true)
        )
      (err ERR-JOB-NOT-FOUND)
    )
  )
)

;; Read-only: get job details
(define-read-only (get-job (job-id uint))
  (begin
    (asserts! (> job-id u0) (err ERR-INVALID-JOB-ID))
    (map-get? jobs job-id)
  )
)

;; Read-only: get bid for a job and bidder
(define-read-only (get-bid (job-id uint) (bidder principal))
  (begin
    (asserts! (> job-id u0) (err ERR-INVALID-JOB-ID))
    (map-get? bids {job-id: job-id, bidder: bidder})
  )
)

;; Read-only: get bid count for job
(define-read-only (get-bid-count (job-id uint))
  (begin
    (asserts! (> job-id u0) (err ERR-INVALID-JOB-ID))
    (default-to u0 (map-get? job-bid-count job-id))
  )
)

;; Read-only: get total jobs
(define-read-only (get-total-jobs)
  (var-get job-counter)
)

;; Read-only: get admin
(define-read-only (get-admin)
  (ok (var-get admin))
)

;; Read-only: check if paused
(define-read-only (is-paused)
  (ok (var-get paused))
)

;; Read-only: get job status
(define-read-only (get-job-status (job-id uint))
  (begin
    (asserts! (> job-id u0) (err ERR-INVALID-JOB-ID))
    (match (map-get? jobs job-id)
      job (ok (get status job))
      (err ERR-JOB-NOT-FOUND)
    )
  )
)

;; Read-only: get assigned freelancer
(define-read-only (get-assigned-to (job-id uint))
  (begin
    (asserts! (> job-id u0) (err ERR-INVALID-JOB-ID))
    (match (map-get? jobs job-id)
      job (ok (get assigned-to job))
      (err ERR-JOB-NOT-FOUND)
    )
  )
)

;; Private helper to check if status is valid
(define-private (is-valid-status (status (string-ascii 20)))
  (or 
    (is-eq status STATUS-OPEN)
    (is-eq status STATUS-BIDDING)
    (is-eq status STATUS-ASSIGNED)
    (is-eq status STATUS-IN-PROGRESS)
    (is-eq status STATUS-COMPLETED)
    (is-eq status STATUS-CANCELLED)
    (is-eq status STATUS-DISPUTED)
  )
)