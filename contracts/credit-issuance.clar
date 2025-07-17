;; Credit Issuance Contract
;; Generates verified carbon offset tokens linked to emission reduction projects

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-INVALID-INPUT (err u201))
(define-constant ERR-CREDIT-NOT-FOUND (err u202))
(define-constant ERR-INSUFFICIENT-REDUCTION (err u203))
(define-constant ERR-PROJECT-NOT-VERIFIED (err u204))

;; Data Variables
(define-data-var next-credit-id uint u1)

;; Data Maps
(define-map carbon-credits
  { credit-id: uint }
  {
    project-id: uint,
    owner: principal,
    amount: uint,
    issue-date: uint,
    vintage-year: uint,
    methodology: (string-ascii 100),
    status: (string-ascii 20),
    metadata: (string-ascii 200)
  }
)

(define-map credit-requests
  { request-id: uint }
  {
    project-id: uint,
    requester: principal,
    amount: uint,
    description: (string-ascii 200),
    status: (string-ascii 20),
    request-date: uint
  }
)

(define-data-var next-request-id uint u1)

;; Public Functions

;; Request credit issuance
(define-public (request-credit-issuance (amount uint) (project-id uint) (description (string-ascii 200)))
  (let ((request-id (var-get next-request-id)))
    (asserts! (> amount u0) ERR-INVALID-INPUT)
    (asserts! (> (len description) u0) ERR-INVALID-INPUT)

    ;; Check if project exists and is verified (would call carbon-footprint contract)
    ;; For now, simplified validation
    (asserts! (> project-id u0) ERR-INVALID-INPUT)

    (map-set credit-requests
      { request-id: request-id }
      {
        project-id: project-id,
        requester: tx-sender,
        amount: amount,
        description: description,
        status: "pending",
        request-date: block-height
      }
    )

    (var-set next-request-id (+ request-id u1))
    (ok request-id)
  )
)

;; Issue carbon credits (authorized issuers only)
(define-public (issue-credits (request-id uint) (vintage-year uint) (methodology (string-ascii 100)))
  (let (
    (request (unwrap! (map-get? credit-requests { request-id: request-id }) ERR-CREDIT-NOT-FOUND))
    (credit-id (var-get next-credit-id))
  )
    ;; In production, add issuer authorization check
    (asserts! (is-eq (get status request) "pending") ERR-INVALID-INPUT)
    (asserts! (> vintage-year u2020) ERR-INVALID-INPUT)
    (asserts! (> (len methodology) u0) ERR-INVALID-INPUT)

    ;; Create the carbon credit
    (map-set carbon-credits
      { credit-id: credit-id }
      {
        project-id: (get project-id request),
        owner: (get requester request),
        amount: (get amount request),
        issue-date: block-height,
        vintage-year: vintage-year,
        methodology: methodology,
        status: "active",
        metadata: (get description request)
      }
    )

    ;; Update request status
    (map-set credit-requests
      { request-id: request-id }
      (merge request { status: "approved" })
    )

    (var-set next-credit-id (+ credit-id u1))
    (ok credit-id)
  )
)

;; Transfer credit ownership
(define-public (transfer-credit (credit-id uint) (new-owner principal))
  (let ((credit (unwrap! (map-get? carbon-credits { credit-id: credit-id }) ERR-CREDIT-NOT-FOUND)))
    (asserts! (is-eq (get owner credit) tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status credit) "active") ERR-INVALID-INPUT)

    (map-set carbon-credits
      { credit-id: credit-id }
      (merge credit { owner: new-owner })
    )
    (ok true)
  )
)

;; Split carbon credit
(define-public (split-credit (credit-id uint) (split-amount uint))
  (let (
    (credit (unwrap! (map-get? carbon-credits { credit-id: credit-id }) ERR-CREDIT-NOT-FOUND))
    (new-credit-id (var-get next-credit-id))
  )
    (asserts! (is-eq (get owner credit) tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status credit) "active") ERR-INVALID-INPUT)
    (asserts! (> split-amount u0) ERR-INVALID-INPUT)
    (asserts! (< split-amount (get amount credit)) ERR-INVALID-INPUT)

    ;; Update original credit
    (map-set carbon-credits
      { credit-id: credit-id }
      (merge credit { amount: (- (get amount credit) split-amount) })
    )

    ;; Create new credit with split amount
    (map-set carbon-credits
      { credit-id: new-credit-id }
      (merge credit {
        amount: split-amount,
        issue-date: block-height
      })
    )

    (var-set next-credit-id (+ new-credit-id u1))
    (ok new-credit-id)
  )
)

;; Read-only Functions

(define-read-only (get-credit (credit-id uint))
  (map-get? carbon-credits { credit-id: credit-id })
)

(define-read-only (get-credit-request (request-id uint))
  (map-get? credit-requests { request-id: request-id })
)

(define-read-only (get-credits-by-owner (owner principal))
  ;; In production, implement pagination
  (ok "Use indexer for efficient queries")
)

(define-read-only (get-next-credit-id)
  (var-get next-credit-id)
)

(define-read-only (get-next-request-id)
  (var-get next-request-id)
)
