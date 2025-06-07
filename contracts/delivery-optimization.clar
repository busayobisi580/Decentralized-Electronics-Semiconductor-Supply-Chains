;; Delivery Optimization Contract
;; Optimizes semiconductor delivery routes and schedules

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u500))
(define-constant ERR_DELIVERY_NOT_FOUND (err u501))
(define-constant ERR_INVALID_STATUS (err u502))
(define-constant ERR_ROUTE_NOT_FOUND (err u503))

(define-map delivery-routes
  { route-id: uint }
  {
    origin: uint,
    destination: uint,
    distance: uint,
    estimated-time: uint,
    cost: uint,
    priority-level: uint,
    active: bool
  }
)

(define-map deliveries
  { delivery-id: uint }
  {
    wafer-id: uint,
    route-id: uint,
    quantity: uint,
    scheduled-time: uint,
    actual-departure: uint,
    actual-arrival: uint,
    status: uint, ;; 0: scheduled, 1: in-transit, 2: delivered, 3: delayed, 4: cancelled
    carrier: principal,
    tracking-info: (string-ascii 100)
  }
)

(define-map route-optimization
  { optimization-id: uint }
  {
    routes: (list 10 uint),
    total-distance: uint,
    total-cost: uint,
    total-time: uint,
    efficiency-score: uint,
    created-at: uint
  }
)

(define-data-var next-route-id uint u1)
(define-data-var next-delivery-id uint u1)
(define-data-var next-optimization-id uint u1)

(define-public (create-route (origin uint) (destination uint) (distance uint) (estimated-time uint) (cost uint) (priority-level uint))
  (let ((route-id (var-get next-route-id)))
    (map-set delivery-routes
      { route-id: route-id }
      {
        origin: origin,
        destination: destination,
        distance: distance,
        estimated-time: estimated-time,
        cost: cost,
        priority-level: priority-level,
        active: true
      }
    )
    (var-set next-route-id (+ route-id u1))
    (ok route-id)
  )
)

(define-public (schedule-delivery (wafer-id uint) (route-id uint) (quantity uint) (scheduled-time uint) (tracking-info (string-ascii 100)))
  (let ((delivery-id (var-get next-delivery-id))
        (route (unwrap! (map-get? delivery-routes { route-id: route-id }) ERR_ROUTE_NOT_FOUND)))
    (map-set deliveries
      { delivery-id: delivery-id }
      {
        wafer-id: wafer-id,
        route-id: route-id,
        quantity: quantity,
        scheduled-time: scheduled-time,
        actual-departure: u0,
        actual-arrival: u0,
        status: u0,
        carrier: tx-sender,
        tracking-info: tracking-info
      }
    )
    (var-set next-delivery-id (+ delivery-id u1))
    (ok delivery-id)
  )
)

(define-public (update-delivery-status (delivery-id uint) (new-status uint) (tracking-info (string-ascii 100)))
  (let ((delivery (unwrap! (map-get? deliveries { delivery-id: delivery-id }) ERR_DELIVERY_NOT_FOUND)))
    (asserts! (<= new-status u4) ERR_INVALID_STATUS)
    (let ((updated-delivery (merge delivery {
            status: new-status,
            tracking-info: tracking-info,
            actual-departure: (if (is-eq new-status u1) block-height (get actual-departure delivery)),
            actual-arrival: (if (is-eq new-status u2) block-height (get actual-arrival delivery))
          })))
      (map-set deliveries
        { delivery-id: delivery-id }
        updated-delivery
      )
      (ok true)
    )
  )
)

(define-public (optimize-routes (route-list (list 10 uint)))
  (let ((optimization-id (var-get next-optimization-id))
        (total-metrics (calculate-route-metrics route-list)))
    (map-set route-optimization
      { optimization-id: optimization-id }
      {
        routes: route-list,
        total-distance: (get total-distance total-metrics),
        total-cost: (get total-cost total-metrics),
        total-time: (get total-time total-metrics),
        efficiency-score: (get efficiency-score total-metrics),
        created-at: block-height
      }
    )
    (var-set next-optimization-id (+ optimization-id u1))
    (ok optimization-id)
  )
)

(define-private (calculate-route-metrics (route-list (list 10 uint)))
  (fold calculate-single-route route-list { total-distance: u0, total-cost: u0, total-time: u0, efficiency-score: u0 })
)

(define-private (calculate-single-route (route-id uint) (acc { total-distance: uint, total-cost: uint, total-time: uint, efficiency-score: uint }))
  (match (map-get? delivery-routes { route-id: route-id })
    route {
      total-distance: (+ (get total-distance acc) (get distance route)),
      total-cost: (+ (get total-cost acc) (get cost route)),
      total-time: (+ (get total-time acc) (get estimated-time route)),
      efficiency-score: (+ (get efficiency-score acc) (/ u1000 (+ (get distance route) (get cost route))))
    }
    acc
  )
)

(define-read-only (get-route (route-id uint))
  (map-get? delivery-routes { route-id: route-id })
)

(define-read-only (get-delivery (delivery-id uint))
  (map-get? deliveries { delivery-id: delivery-id })
)

(define-read-only (get-optimization (optimization-id uint))
  (map-get? route-optimization { optimization-id: optimization-id })
)
