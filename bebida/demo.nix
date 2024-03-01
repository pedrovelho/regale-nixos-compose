{ ... }:
{
  environment.etc."demo/pod-sleep-100.yml" = {
    text = ''
      apiVersion: v1
      kind: Pod
      metadata:
        name: busybox-1
      spec:
        containers:
        - name: busybox
          image: busybox:1.28
          args:
          - sleep
          - "100"
    '';
  };
}
