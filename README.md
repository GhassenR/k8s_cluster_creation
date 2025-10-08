# Creating a Kubernetes Cluster with Ansible Playbooks

Follow these steps to create a Kubernetes cluster using Ansible playbooks:

1. **Prerequisites:**
    - OS : ubuntu 22.04.
    - Have SSH access to the servers where you want to create the Kubernetes cluster.
    - Change `srever ip` used in script 

2. **Make the files executable:**
    ```bash
    chmod +x k8s_installer.sh
    ```

3. **Generate key and copy it to targer system:**
    ```bash
    ./copy_id.sh
    ```

4. **Execute k8s installation**
    ```bash
    ./install-cluster.sh
    ```
