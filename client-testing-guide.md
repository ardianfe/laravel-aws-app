# Laravel API Client Testing Guide

## 🌐 Application Endpoints

**Primary URL**: http://laravel-aws-app-alb-1787439313.ap-southeast-1.elb.amazonaws.com

## 🧪 Health Check Endpoints

### 1. Basic Health Check
```bash
curl -i http://laravel-aws-app-alb-1787439313.ap-southeast-1.elb.amazonaws.com/health
```

**Expected Response:**
```json
{
    "status": "ok",
    "database": "connected",
    "timestamp": "2026-01-12T04:00:00.000000Z"
}
```

### 2. Database Health Check
```bash
curl -i http://laravel-aws-app-alb-1787439313.ap-southeast-1.elb.amazonaws.com/health/database
```

## 🔥 Load Testing for Tryout Events

### Test Burst Scaling (Simulate 100 concurrent users)
```bash
# Install Apache Bench (if not installed)
# Ubuntu/Debian: sudo apt install apache2-utils
# macOS: brew install httpie

# Test concurrent requests
ab -n 1000 -c 100 http://laravel-aws-app-alb-1787439313.ap-southeast-1.elb.amazonaws.com/health

# Alternative with curl (simple test)
for i in {1..10}; do
  curl -s -o /dev/null -w "%{http_code} - %{time_total}s\n" \
    http://laravel-aws-app-alb-1787439313.ap-southeast-1.elb.amazonaws.com/health &
done; wait
```

## 📱 Frontend Integration Examples

### JavaScript (Fetch API)
```javascript
// Health check
const healthCheck = async () => {
    try {
        const response = await fetch('http://laravel-aws-app-alb-1787439313.ap-southeast-1.elb.amazonaws.com/health');
        const data = await response.json();
        console.log('API Status:', data.status);
        return data.status === 'ok';
    } catch (error) {
        console.error('API Error:', error);
        return false;
    }
};

// API call example
const callAPI = async (endpoint, options = {}) => {
    const baseURL = 'http://laravel-aws-app-alb-1787439313.ap-southeast-1.elb.amazonaws.com';
    
    try {
        const response = await fetch(`${baseURL}${endpoint}`, {
            headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
            },
            ...options
        });
        
        return await response.json();
    } catch (error) {
        console.error('API call failed:', error);
        throw error;
    }
};
```

### Python (Requests)
```python
import requests
import time
import threading

# Health check
def health_check():
    try:
        response = requests.get('http://laravel-aws-app-alb-1787439313.ap-southeast-1.elb.amazonaws.com/health')
        return response.status_code == 200 and response.json().get('status') == 'ok'
    except:
        return False

# Load test simulation
def simulate_user_load(num_requests=10):
    def make_request():
        start_time = time.time()
        try:
            response = requests.get('http://laravel-aws-app-alb-1787439313.ap-southeast-1.elb.amazonaws.com/health')
            end_time = time.time()
            print(f"Response: {response.status_code} - Time: {end_time - start_time:.2f}s")
        except Exception as e:
            print(f"Error: {e}")
    
    threads = []
    for _ in range(num_requests):
        thread = threading.Thread(target=make_request)
        threads.append(thread)
        thread.start()
    
    for thread in threads:
        thread.join()

# Run load test
simulate_user_load(50)  # Simulate 50 concurrent users
```

### React.js Component
```jsx
import React, { useState, useEffect } from 'react';

const APIHealthMonitor = () => {
    const [healthStatus, setHealthStatus] = useState('checking...');
    const [responseTime, setResponseTime] = useState(null);
    
    const checkHealth = async () => {
        const startTime = Date.now();
        try {
            const response = await fetch('http://laravel-aws-app-alb-1787439313.ap-southeast-1.elb.amazonaws.com/health');
            const data = await response.json();
            const endTime = Date.now();
            
            setHealthStatus(data.status);
            setResponseTime(endTime - startTime);
        } catch (error) {
            setHealthStatus('error');
            setResponseTime(null);
        }
    };
    
    useEffect(() => {
        checkHealth();
        const interval = setInterval(checkHealth, 30000); // Check every 30 seconds
        return () => clearInterval(interval);
    }, []);
    
    return (
        <div style={{
            padding: '20px',
            border: `2px solid ${healthStatus === 'ok' ? 'green' : 'red'}`,
            borderRadius: '8px'
        }}>
            <h3>Laravel API Status</h3>
            <p>Status: <strong>{healthStatus}</strong></p>
            {responseTime && <p>Response Time: {responseTime}ms</p>}
        </div>
    );
};

export default APIHealthMonitor;
```

## 🔧 Debugging Commands

### Check Load Balancer Health
```bash
# Check target group health
aws elbv2 describe-target-health \
    --target-group-arn arn:aws:elasticloadbalancing:ap-southeast-1:975628797176:targetgroup/laravel-aws-app-tg/a8c36acd30b4e81e \
    --region ap-southeast-1
```

### Check ECS Service Status
```bash
# Check ECS service status
aws ecs describe-services \
    --cluster laravel-aws-app \
    --services laravel-aws-app-staging \
    --region ap-southeast-1
```

### View Application Logs
```bash
# View ECS task logs
aws logs tail /ecs/laravel-aws-app --follow --region ap-southeast-1
```

## 📊 Monitoring Scaling During Tryout Events

### Monitor ECS Service Scaling
```bash
# Watch service scaling in real-time
watch -n 5 'aws ecs describe-services \
    --cluster laravel-aws-app \
    --services laravel-aws-app-staging \
    --region ap-southeast-1 \
    --query "services[0].{RunningTasks:runningCount,DesiredTasks:desiredCount}"'
```

### Monitor Target Group Health
```bash
# Watch healthy targets
watch -n 10 'aws elbv2 describe-target-health \
    --target-group-arn arn:aws:elasticloadbalancing:ap-southeast-1:975628797176:targetgroup/laravel-aws-app-tg/a8c36acd30b4e81e \
    --region ap-southeast-1 \
    --query "TargetHealthDescriptions[*].{Target:Target.Id,Health:TargetHealth.State}"'
```

## 🚨 Expected Response Codes

- **200**: Healthy API response
- **503**: Service temporarily unavailable (scaling in progress)
- **502**: Bad Gateway (container starting up)
- **504**: Gateway timeout (container overloaded)

## 📈 Performance Expectations

### Normal Traffic (1-10 users)
- Response Time: 100-300ms
- Availability: 99.9%
- Scaling: 1 container

### Tryout Event Traffic (100-1000 users)
- Response Time: 200-500ms (during scale-up)
- Availability: 99.5%+ (brief unavailability during scaling)
- Scaling: Auto-scales to 5-20+ containers
- Scale-up Time: 30-60 seconds

### Load Test Results to Expect
```bash
# Successful scaling should show:
# - Initial slow responses (containers starting)
# - Gradual improvement as new containers come online
# - Stable performance once scaled
```

## 🔍 Troubleshooting

### If Health Check Fails
1. Check ECS service is running
2. Verify security group allows port 80
3. Check container logs for errors
4. Ensure database connectivity

### If Load Balancer Returns 502/503
1. Wait for containers to fully start (2-3 minutes)
2. Check target group health
3. Verify Docker container exposes port 80
4. Check if Laravel app is binding to 0.0.0.0:80

### If Scaling is Slow
1. Monitor CloudWatch metrics
2. Check ECS service auto-scaling policies
3. Verify target group health check intervals
4. Consider reducing health check grace period