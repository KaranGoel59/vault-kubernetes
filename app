---
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  namespace: aa 
  name: beta-bookapp
spec:
  replicas: 1
  selector:
    matchLabels:
      service: beta-bookapp
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: "10%"
      maxUnavailable: 0

  minReadySeconds: 30
  template:
    metadata:
      labels:
        service: beta-bookapp
    spec:
      containers:
      - name: beta-bookapp
        image: asia.gcr.io/ct-prod-infra/bookapp:796
        imagePullPolicy: IfNotPresent
        resources:
         limits:
           memory: "8G"
           cpu: "4"
         requests:
           memory: "4G"
           cpu: "3"
        
        env:
        - name: STARTCMD
          value: "java -server -Xms1g -Xmx3g -Dct.ctconfig.profilename=prod,gcp,pci -Dct.ctconfig.consul.fetch.base.url=http://ct-config.cltp.com:9001/hq/ct-config/api/resource/fetch -Dct.ctconfig.consul.server=http://${HOST_IP}:8500 -Djava.net.preferIPv4Stack=true -d64 -Dnewrelic.config.distributed_tracing.enabled=true -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=9004 -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false -XX:+UseG1GC -Dct.common.servertype=bookapp -Dapp.context.path=book -Dspring.profiles.active=prod,gcp,pci -javaagent:/opt/newrelic/newrelic.jar -jar app.war"
        - name: HOST_IP
          valueFrom:
            fieldRef:
              fieldPath: status.hostIP
        - name: FILEBEAT
          value: "true"
        - name: FILEBEAT_APP_NAME
          value: "beta-bookapp"
        - name: FILEBEAT_APP_TOPIC
          value: "a2-apps"
        - name: FILEBEAT_ITI_TOPIC
          value: "a2-access"
        - name: NEW_RELIC_APP_NAME
          value: "beta-bookapp"
        - name: FILEBEAT_ACCESS_LOGFILE
          value: "/opt/cal/logs/access.log"
        - name: FILEBEAT_APP_LOGFILE
          value: "/opt/cal/logs/application.log"
        ports:
        - containerPort: 9080
        readinessProbe:
          tcpSocket:
            port: 9080
          initialDelaySeconds: 60
          timeoutSeconds: 5
        readinessProbe:
          httpGet:
             path: /book/actuator/health
             port: 9080
          initialDelaySeconds: 60
          timeoutSeconds: 5
        livenessProbe:
          httpGet:
             path: /book/actuator/health
             port: 9080
          initialDelaySeconds: 60
          timeoutSeconds: 5
          periodSeconds: 60
---
kind: Service
apiVersion: v1
metadata:
  namespace: aa
  name: beta-bookapp
  annotations:
    cloud.google.com/load-balancer-type: "Internal" 
spec:
  type: LoadBalancer
  selector:
    service: beta-bookapp
  loadBalancerIP: 10.163.0.83
  ports:
  - protocol: TCP
    port: 80
    targetPort: 9080

---

apiVersion: autoscaling/v1
kind: HorizontalPodAutoscaler
metadata:
  name: beta-bookapp
  namespace: aa
spec:
  maxReplicas: 1
  minReplicas: 1
  scaleTargetRef:
    apiVersion: extensions/v1beta1
    kind: Deployment
    name: beta-bookapp
  targetCPUUtilizationPercentage: 70
