// Package health provides HTTP handlers for health check endpoints.
// It supports Kubernetes-style liveness and readiness probes.
package health

import (
	"net/http"
	"sync/atomic"

	"github.com/gin-gonic/gin"
)

// Handler manages health check state and HTTP handlers.
type Handler struct {
	ready atomic.Bool
}

// NewHandler creates a new health check handler.
// The handler starts in a not-ready state.
func NewHandler() *Handler {
	return &Handler{}
}

// SetReady marks the service as ready to accept traffic.
func (h *Handler) SetReady(ready bool) {
	h.ready.Store(ready)
}

// IsReady returns the current readiness state.
func (h *Handler) IsReady() bool {
	return h.ready.Load()
}

// Health handles the basic health check endpoint.
// Returns 200 OK if the process is running.
// GET /health
func (h *Handler) Health(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"status": "ok",
	})
}

// Ready handles the readiness check endpoint.
// Returns 200 OK when the service is ready to accept traffic.
// Returns 503 Service Unavailable when not ready.
// GET /health/ready
func (h *Handler) Ready(c *gin.Context) {
	if h.ready.Load() {
		c.JSON(http.StatusOK, gin.H{
			"status": "ready",
		})
		return
	}
	c.JSON(http.StatusServiceUnavailable, gin.H{
		"status": "not ready",
	})
}

// Live handles the liveness check endpoint.
// Returns 200 OK if the process is running (same as /health).
// This is the Kubernetes convention alias.
// GET /health/live
func (h *Handler) Live(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"status": "live",
	})
}

// RegisterRoutes registers all health check routes on the given gin.Engine.
// Routes are unauthenticated for infrastructure health checks.
func (h *Handler) RegisterRoutes(engine *gin.Engine) {
	engine.GET("/health", h.Health)
	engine.GET("/health/ready", h.Ready)
	engine.GET("/health/live", h.Live)
}
