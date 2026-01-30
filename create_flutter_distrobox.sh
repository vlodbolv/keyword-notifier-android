distrobox create --name flutter-dev \
  --image ubuntu:24.04 \
  --additional-flags "--device /dev/bus/usb/001 --device /dev/bus/usb/002 --userns=keep-id --group-add keep-groups"
