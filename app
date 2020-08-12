---
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  namespace: air
  name: canary-airapi4misc
spec:
  replicas: 1
  selector:
    matchLabels:
      service: airapi4misc

  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 10%
      maxUnavailable: 0
  minReadySeconds: 30
  template:
    metadata:
      labels:
        service: airapi4misc
    spec:
      containers:
      - env:
        - name: HOST_IP
          valueFrom:
            fieldRef:
              apiVersion: v1
              fieldPath: status.hostIP
        - name: STARTCMD
          value: java -server -XX:+UseParallelOldGC -Xss384k -Xms3g -Xmx3g -d64 -Dct.ctconfig.consul.server=http://$(HOST_IP):8500
            -Djava.net.preferIPv4Stack=true -XX:ParallelGCThreads=4 -Dnewrelic.config.distributed_tracing.enabled=true
            -Dlog4j.logging.path=/var/log/tomcat7 -Dct.common.contexts.excludelist=db-context.xml
            -Dct.common.local.serverid=11 -Dnet.spy.log.LoggerImpl=net.spy.memcached.compat.log.Log4JLogger
            -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=9004
            -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false
            -Dctrel=release1 -Dctport=9080 -Dct.common.servertype=airapi4book -Dapp.context.path=airservice
            -Dwrapper.java.umask=0002 -Dspring.profiles.active=prod,docker,airapi4book,gcp
            -javaagent:/opt/newrelic/newrelic.jar -jar app.jar
        - name: FILEBEAT
          value: 'true'
        - name: FILEBEAT_APP_NAME
          value: canary-airapi4misc
        - name: FILEBEAT_APP_TOPIC
          value: air-search-app
        - name: FILEBEAT_ITI_TOPIC
          value: airsrch-access
        - name: NEW_RELIC_APP_NAME
          value: canary-airapi4misc
        - name: FILEBEAT_APP_LOGFILE
          value: /var/log/tomcat7/catalina.out
        - name: FILEBEAT_ACCESS_LOGFILE
          value: /var/log/tomcat7/access.*.log
        - name: LASTRESTART
          value: '200330063604'
        image: asia.gcr.io/ct-prod-infra/air-service:3613
        imagePullPolicy: IfNotPresent
        livenessProbe:
          failureThreshold: 3
          httpGet:
            path: /health
            port: 9080
            scheme: HTTP
          initialDelaySeconds: 60
          periodSeconds: 60
          successThreshold: 1
          timeoutSeconds: 5
        name: canary-airapi4misc
        ports:
        - containerPort: 9080
          protocol: TCP
        readinessProbe:
          failureThreshold: 3
          httpGet:
            path: /airservice/healthcheck
            port: 9080
            scheme: HTTP
          initialDelaySeconds: 120
          periodSeconds: 10
          successThreshold: 1
          timeoutSeconds: 5
        resources:
          limits:
            cpu: '4'
            memory: 7G
          requests:
            cpu: 500m
            memory: 4G
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
        volumeMounts:
        - mountPath: /etc/filebeat/filebeat.yml
          name: filebeat4air
          readOnly: true
          subPath: filebeat.yml
      dnsPolicy: ClusterFirst
      restartPolicy: Always
      schedulerName: default-scheduler
      securityContext: {}
      terminationGracePeriodSeconds: 30
      tolerations:
      - effect: NoSchedule
        key: cloud.google.com/gke-preemptible
        operator: Equal
        value: 'true'
      volumes:
      - configMap:
          defaultMode: 420
          name: filebeat4air
        name: filebeat4air
