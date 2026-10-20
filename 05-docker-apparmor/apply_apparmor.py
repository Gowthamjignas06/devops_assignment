import docker

# Create a Docker client
client = docker.from_env()

# Build the Docker image
print("Building image from Dockerfile...")
client.images.build(path=".", tag="flask-apparmor")

# Run the container with the AppArmor profile
print("Running container with AppArmor profile...")
container = client.containers.run(
    "flask-apparmor",
    ports={'5000/tcp': 5000},
    security_opt=["apparmor=my-apparmor-profile"],
    detach=True
)

print(f"Container started: {container.short_id}")

# Verify AppArmor profile applied
print("Inspecting container to verify AppArmor profile...")
container_info = client.api.inspect_container(container.id)
apparmor_profile = container_info['HostConfig']['SecurityOpt']

print(f"AppArmor profile applied: {apparmor_profile}")
# AppArmorProfile shows what the kernel actually enforced
print(f"AppArmorProfile (enforced): {container_info.get('AppArmorProfile')}")

# Stop the container (and remove it, so the script can be re-run)
print("Stopping the container...")
container.stop()
container.remove()
