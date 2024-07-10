FROM ros:noetic-ros-base-focal

ENV DEBIAN_FRONTEND=noninteractive
ENV ROS_DISTRO noetic
ARG USERNAME=m
ARG PROJECT_NAME=dm_vio

RUN apt update && \
    apt install -y vim tree wget curl git unzip ninja-build && \
    apt install -y zsh && \
    apt install -y libeigen3-dev python3-catkin-tools libsuitesparse-dev libboost-all-dev libyaml-cpp-dev && \
    apt install -y libtbb-dev libgl1-mesa-dev libglew-dev pkg-config libegl1-mesa-dev \ 
                   libwayland-dev libxkbcommon-dev wayland-protocols && \
    apt install -y ros-${ROS_DISTRO}-cv-bridge ros-${ROS_DISTRO}-image-transport && \
    apt install -y ros-${ROS_DISTRO}-tf-conversions ros-${ROS_DISTRO}-tf ros-${ROS_DISTRO}-tf2 && \
    DEBIAN_FRONTEND=noninteractive apt install -y keyboard-configuration && \
    apt clean && rm -rf /var/lib/apt/lists/*

# install GTSAM
WORKDIR /pkg/GTSAM
RUN git clone --recursive https://github.com/borglab/gtsam.git && cd gtsam && git checkout 4.2a6 && \
    mkdir build && cd build && \
    cmake -GNinja -DGTSAM_POSE3_EXPMAP=ON -DGTSAM_ROT3_EXPMAP=ON -DGTSAM_USE_SYSTEM_EIGEN=ON -DGTSAM_BUILD_WITH_MARCH_NATIVE=OFF .. && \
    ninja && ninja install && ninja clean && ldconfig

# install Pangolin
WORKDIR /pkg/pangolin
RUN git clone --recursive https://github.com/stevenlovegrove/Pangolin.git && cd Pangolin && git checkout v0.6 && \
    mkdir build && cd build && cmake -GNinja .. && \
    ninja && ninja install && ninja clean && ldconfig

# setup user
ARG USER_UID=1000
ARG USER_GID=$USER_UID
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME
USER $USERNAME

# install zsh & set zsh as the default shell
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended && \
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions && \
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting && \
    sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/g' /home/$USERNAME/.zshrc
SHELL ["/bin/zsh", "-c"]

WORKDIR /home/${USERNAME}
RUN git clone --depth 1 --recursive https://github.com/EnderMandS/dm-vio-ros.git ${PROJECT_NAME} && \
    chmod 777 -R /home/${USERNAME}/${PROJECT_NAME} && cd ./${PROJECT_NAME} && \
    cd ./main && mkdir build && cd build && cmake -GNinja .. && ninja && \
    cd /home/${USERNAME}/${PROJECT_NAME}/ros_ws && . /opt/ros/${ROS_DISTRO}/setup.sh && \
    catkin_make -DCATKIN_WHITELIST_PACKAGES="" -DCMAKE_BUILD_TYPE=Release && \
    echo "source /home/m/dm_vio/ros_ws/devel/setup.zsh" >> /home/${USERNAME}/.zshrc

ENTRYPOINT [ "/bin/zsh" ]
# ENTRYPOINT [ "/home/m/code/ros_ws/setup.zsh" ]