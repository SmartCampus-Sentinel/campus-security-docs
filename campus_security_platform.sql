-- 1. 创建数据库（若不存在）
CREATE DATABASE IF NOT EXISTS campus_security_platform DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE campus_security_platform;

-- 2. 创建角色表（sys_role）- 无外键依赖，优先创建
CREATE TABLE IF NOT EXISTS sys_role (
                                        role_id BIGINT(20) NOT NULL AUTO_INCREMENT COMMENT '角色唯一标识',
                                        role_name VARCHAR(50) NOT NULL COMMENT '角色名称（如超级管理员、安保人员）',
                                        permissions VARCHAR(500) DEFAULT NULL COMMENT '权限列表（逗号分隔，如device:list,alarm:handle）',
                                        PRIMARY KEY (role_id),
                                        UNIQUE KEY uk_role_name (role_name) COMMENT '角色名称唯一'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='角色表';

-- 3. 创建系统用户表（sys_user）- 依赖sys_role表
CREATE TABLE IF NOT EXISTS sys_user (
                                        user_id BIGINT(20) NOT NULL AUTO_INCREMENT COMMENT '用户唯一标识',
                                        username VARCHAR(50) NOT NULL COMMENT '登录用户名',
                                        password VARCHAR(100) NOT NULL COMMENT 'BCrypt加密后的密码',
                                        role_id BIGINT(20) NOT NULL COMMENT '用户所属角色ID',
                                        phone VARCHAR(20) DEFAULT NULL COMMENT '用户手机号（用于紧急通知）',
                                        status TINYINT(1) NOT NULL DEFAULT 1 COMMENT '状态（0-禁用，1-启用）',
                                        PRIMARY KEY (user_id),
                                        UNIQUE KEY uk_username (username) COMMENT '用户名唯一',
                                        UNIQUE KEY uk_phone (phone) COMMENT '手机号唯一',
                                        CONSTRAINT fk_sys_user_role_id FOREIGN KEY (role_id) REFERENCES sys_role (role_id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='系统用户表（管理员、安保人员）';

-- 4. 创建设备信息表（device_info）- 无外键依赖
CREATE TABLE IF NOT EXISTS device_info (
                                           device_id VARCHAR(32) NOT NULL COMMENT '设备唯一标识（自定义编码，如CAM-001、SENSOR-002）',
                                           device_type VARCHAR(20) NOT NULL COMMENT '设备类型（摄像头/烟感传感器/温感传感器）',
                                           location VARCHAR(100) NOT NULL COMMENT '设备安装位置（如教学楼A栋1楼大厅）',
                                           ip_address VARCHAR(50) DEFAULT NULL COMMENT '设备IP地址（传感器可能无IP）',
                                           status TINYINT(1) NOT NULL DEFAULT 1 COMMENT '状态（0-离线，1-在线）',
                                           heartbeat_time DATETIME DEFAULT NULL COMMENT '最后心跳时间',
                                           create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '设备录入时间',
                                           PRIMARY KEY (device_id),
                                           UNIQUE KEY uk_ip_address (ip_address) COMMENT 'IP地址唯一（若存在）'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='设备信息表';

-- 5. 创建报警事件表（alarm_event）- 依赖device_info表
CREATE TABLE IF NOT EXISTS alarm_event (
                                           alarm_id VARCHAR(32) NOT NULL COMMENT '报警唯一标识（如A-20240501-001）',
                                           alarm_type VARCHAR(50) NOT NULL COMMENT '报警类型（消防通道占用/危险区域闯入/火焰烟雾等）',
                                           risk_level TINYINT(1) NOT NULL COMMENT '风险等级（1-紧急，2-重要，3-一般）',
                                           location VARCHAR(100) NOT NULL COMMENT '报警发生位置',
                                           device_id VARCHAR(32) NOT NULL COMMENT '触发报警的设备ID',
                                           alarm_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '报警发生时间',
                                           status TINYINT(1) NOT NULL DEFAULT 0 COMMENT '处置状态（0-未处置，1-处置中，2-已完成，3-已归档）',
                                           screenshot_url VARCHAR(255) DEFAULT NULL COMMENT '报警现场截图URL',
                                           PRIMARY KEY (alarm_id),
                                           CONSTRAINT fk_alarm_event_device_id FOREIGN KEY (device_id) REFERENCES device_info (device_id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='报警事件表';

-- 6. 创建报警处置记录表（alarm_disposal）- 依赖alarm_event和sys_user表
CREATE TABLE IF NOT EXISTS alarm_disposal (
                                              disposal_id BIGINT(20) NOT NULL AUTO_INCREMENT COMMENT '处置记录唯一标识',
                                              alarm_id VARCHAR(32) NOT NULL COMMENT '关联的报警ID',
                                              disposer_id BIGINT(20) NOT NULL COMMENT '处置人ID',
                                              disposal_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '处置时间',
                                              disposal_content TEXT DEFAULT NULL COMMENT '处置内容描述',
                                              result_photo_url VARCHAR(255) DEFAULT NULL COMMENT '处置结果照片URL',
                                              PRIMARY KEY (disposal_id),
                                              CONSTRAINT fk_alarm_disposal_alarm_id FOREIGN KEY (alarm_id) REFERENCES alarm_event (alarm_id) ON DELETE RESTRICT,
                                              CONSTRAINT fk_alarm_disposal_disposer_id FOREIGN KEY (disposer_id) REFERENCES sys_user (user_id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='报警处置记录表';

-- 7. 创建学生隐患上报表（student_report）- 无外键依赖（学生ID直接存储学号，无需单独建表）
CREATE TABLE IF NOT EXISTS student_report (
                                              report_id VARCHAR(32) NOT NULL COMMENT '上报记录唯一标识（如R-20240501-001）',
                                              student_id VARCHAR(50) NOT NULL COMMENT '学生ID（如学号）',
                                              report_type VARCHAR(50) NOT NULL COMMENT '隐患类型（消防设施损坏/通道占用等）',
                                              location VARCHAR(100) NOT NULL COMMENT '隐患位置',
                                              description TEXT DEFAULT NULL COMMENT '隐患补充说明',
                                              media_url VARCHAR(500) DEFAULT NULL COMMENT '媒体文件URL（多个用逗号分隔）',
                                              report_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '上报时间',
                                              audit_status TINYINT(1) NOT NULL DEFAULT 0 COMMENT '审核状态（0-待审核，1-处理中，2-已解决，3-已驳回）',
                                              PRIMARY KEY (report_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='学生隐患上报表';

-- 8. 创建传感器数据表（sensor_data）- 依赖device_info表
CREATE TABLE IF NOT EXISTS sensor_data (
                                           data_id BIGINT(20) NOT NULL AUTO_INCREMENT COMMENT '数据记录唯一标识',
                                           device_id VARCHAR(32) NOT NULL COMMENT '采集数据的传感器ID',
                                           smoke_concentration DECIMAL(10,2) DEFAULT NULL COMMENT '烟感浓度（ppm，仅烟感传感器有值）',
                                           temperature DECIMAL(10,2) DEFAULT NULL COMMENT '温度（℃，仅温感传感器有值）',
                                           collect_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '数据采集时间',
                                           is_abnormal TINYINT(1) NOT NULL DEFAULT 0 COMMENT '是否异常（0-正常，1-异常）',
                                           PRIMARY KEY (data_id),
                                           CONSTRAINT fk_sensor_data_device_id FOREIGN KEY (device_id) REFERENCES device_info (device_id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='传感器数据表';


-- 可选：初始化基础角色数据（超级管理员、安保人员）- 存在则更新权限
INSERT INTO sys_role (role_name, permissions)
VALUES
    ('超级管理员', 'user:manage,device:manage,alarm:manage,system:setting,report:audit'),
    ('安保人员', 'device:view,alarm:handle,alarm:view,report:view')
ON DUPLICATE KEY UPDATE permissions = VALUES(permissions); -- 角色名重复时，更新权限列表

-- 可选：初始化超级管理员用户（用户名：admin，密码：123456）- 存在则更新信息
INSERT INTO sys_user (username, password, role_id, phone, status)
VALUES
    ('admin', '$2a$10$EixZaYb4xU58Gpq1R0yWbeb00LU5qUaK6x8a0t1GQ1GQ1GQ1GQ1GQ', 1, '13800138000', 1)
ON DUPLICATE KEY UPDATE
                     password = VALUES(password),
                     role_id = VALUES(role_id),
                     phone = VALUES(phone),
                     status = VALUES(status); -- 用户名重复时，更新密码、角色、手机号和状态
