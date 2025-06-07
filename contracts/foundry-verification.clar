;; Foundry Verification Contract
;; Validates and manages semiconductor foundries

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_FOUNDRY_NOT_FOUND (err u101))
(define-constant ERR_FOUNDRY_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_CERTIFICATION (err u103))

(define-map foundries
  { foundry-id: uint }
  {
    name: (string-ascii 50),
    location: (string-ascii 100),
    certification-level: uint,
    verified: bool,
    registered-at: uint,
    owner: principal
  }
)

(define-data-var next-foundry-id uint u1)

(define-public (register-foundry (name (string-ascii 50)) (location (string-ascii 100)) (certification-level uint))
  (let ((foundry-id (var-get next-foundry-id)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (<= certification-level u5) ERR_INVALID_CERTIFICATION)
    (map-set foundries
      { foundry-id: foundry-id }
      {
        name: name,
        location: location,
        certification-level: certification-level,
        verified: false,
        registered-at: block-height,
        owner: tx-sender
      }
    )
    (var-set next-foundry-id (+ foundry-id u1))
    (ok foundry-id)
  )
)

(define-public (verify-foundry (foundry-id uint))
  (let ((foundry (unwrap! (map-get? foundries { foundry-id: foundry-id }) ERR_FOUNDRY_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set foundries
      { foundry-id: foundry-id }
      (merge foundry { verified: true })
    )
    (ok true)
  )
)

(define-read-only (get-foundry (foundry-id uint))
  (map-get? foundries { foundry-id: foundry-id })
)

(define-read-only (is-foundry-verified (foundry-id uint))
  (match (map-get? foundries { foundry-id: foundry-id })
    foundry (get verified foundry)
    false
  )
)
