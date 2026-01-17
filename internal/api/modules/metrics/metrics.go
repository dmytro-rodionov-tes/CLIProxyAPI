// Package metrics provides Prometheus metrics collection and exposition for the API server.
// It implements the RouteModuleV2 interface for seamless integration with the module system.
package metrics

import (
	"net/http"
	"strconv"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/router-for-me/CLIProxyAPI/v6/internal/api/modules"
	"github.com/router-for-me/CLIProxyAPI/v6/internal/config"
)

const moduleName = "metrics"

// Module provides Prometheus metrics collection and the /metrics endpoint.
type Module struct {
	mu          sync.Mutex
	enabled     bool
	registered  bool
	registry    *prometheus.Registry
	httpHandler http.Handler

	// Metrics
	requestsTotal    *prometheus.CounterVec
	requestDuration  *prometheus.HistogramVec
	tokensTotal      *prometheus.CounterVec
	credentialsGauge *prometheus.GaugeVec
	errorsTotal      *prometheus.CounterVec
}

// New creates a new metrics module.
func New() *Module {
	return &Module{
		enabled: false,
	}
}

// Name implements RouteModuleV2.
func (m *Module) Name() string {
	return moduleName
}

// Register implements RouteModuleV2.
func (m *Module) Register(ctx modules.Context) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.registered {
		return nil
	}

	// Check if metrics are enabled in config
	m.enabled = ctx.Config != nil && ctx.Config.MetricsEnabled

	// Initialize Prometheus registry and metrics
	m.registry = prometheus.NewRegistry()

	// Register standard Go metrics
	m.registry.MustRegister(prometheus.NewGoCollector())
	m.registry.MustRegister(prometheus.NewProcessCollector(prometheus.ProcessCollectorOpts{}))

	// Initialize custom metrics
	m.requestsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "cliproxy_requests_total",
			Help: "Total number of API requests by model, provider, and status code",
		},
		[]string{"model", "provider", "status"},
	)

	m.requestDuration = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "cliproxy_request_duration_seconds",
			Help:    "Request duration in seconds by model and provider",
			Buckets: prometheus.DefBuckets,
		},
		[]string{"model", "provider"},
	)

	m.tokensTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "cliproxy_tokens_total",
			Help: "Total tokens processed by model and type (input/output)",
		},
		[]string{"model", "type"},
	)

	m.credentialsGauge = prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "cliproxy_credentials_active",
			Help: "Number of active credentials by provider",
		},
		[]string{"provider"},
	)

	m.errorsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "cliproxy_errors_total",
			Help: "Total number of errors by type",
		},
		[]string{"type"},
	)

	// Register metrics with registry
	m.registry.MustRegister(m.requestsTotal)
	m.registry.MustRegister(m.requestDuration)
	m.registry.MustRegister(m.tokensTotal)
	m.registry.MustRegister(m.credentialsGauge)
	m.registry.MustRegister(m.errorsTotal)

	// Create HTTP handler
	m.httpHandler = promhttp.HandlerFor(m.registry, promhttp.HandlerOpts{
		EnableOpenMetrics: true,
	})

	// Register /metrics endpoint (unauthenticated for Prometheus scraping)
	ctx.Engine.GET("/metrics", m.metricsHandler)

	m.registered = true
	return nil
}

// OnConfigUpdated implements RouteModuleV2.
func (m *Module) OnConfigUpdated(cfg *config.Config) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if cfg != nil {
		m.enabled = cfg.MetricsEnabled
	}

	return nil
}

// metricsHandler serves the Prometheus metrics endpoint.
func (m *Module) metricsHandler(c *gin.Context) {
	m.mu.Lock()
	enabled := m.enabled
	handler := m.httpHandler
	m.mu.Unlock()

	if !enabled {
		c.JSON(http.StatusNotFound, gin.H{"error": "metrics endpoint disabled"})
		return
	}

	if handler == nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": "metrics not initialized"})
		return
	}

	handler.ServeHTTP(c.Writer, c.Request)
}

// RecordRequest records a completed API request.
func (m *Module) RecordRequest(model, provider string, statusCode int, duration time.Duration) {
	m.mu.Lock()
	enabled := m.enabled
	m.mu.Unlock()

	if !enabled || m.requestsTotal == nil || m.requestDuration == nil {
		return
	}

	m.requestsTotal.WithLabelValues(model, provider, strconv.Itoa(statusCode)).Inc()
	m.requestDuration.WithLabelValues(model, provider).Observe(duration.Seconds())
}

// RecordTokens records token usage for a request.
func (m *Module) RecordTokens(model string, inputTokens, outputTokens int) {
	m.mu.Lock()
	enabled := m.enabled
	m.mu.Unlock()

	if !enabled || m.tokensTotal == nil {
		return
	}

	if inputTokens > 0 {
		m.tokensTotal.WithLabelValues(model, "input").Add(float64(inputTokens))
	}
	if outputTokens > 0 {
		m.tokensTotal.WithLabelValues(model, "output").Add(float64(outputTokens))
	}
}

// SetCredentialsCount sets the current number of active credentials for a provider.
func (m *Module) SetCredentialsCount(provider string, count int) {
	m.mu.Lock()
	enabled := m.enabled
	m.mu.Unlock()

	if !enabled || m.credentialsGauge == nil {
		return
	}

	m.credentialsGauge.WithLabelValues(provider).Set(float64(count))
}

// RecordError records an error occurrence.
func (m *Module) RecordError(errorType string) {
	m.mu.Lock()
	enabled := m.enabled
	m.mu.Unlock()

	if !enabled || m.errorsTotal == nil {
		return
	}

	m.errorsTotal.WithLabelValues(errorType).Inc()
}

// IsEnabled returns whether metrics collection is enabled.
func (m *Module) IsEnabled() bool {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.enabled
}
