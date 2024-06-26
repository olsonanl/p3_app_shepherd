TOP_DIR = ../..
include $(TOP_DIR)/tools/Makefile.common

TARGET ?= /kb/deployment
DEPLOY_TARGET ?= $(TARGET)
DEPLOY_RUNTIME ?= /disks/patric-common/runtime

SRC_SERVICE_PERL = $(wildcard service-scripts/*.pl)
BIN_SERVICE_PERL = $(addprefix $(BIN_DIR)/,$(basename $(notdir $(SRC_SERVICE_PERL))))
DEPLOY_SERVICE_PERL = $(addprefix $(SERVICE_DIR)/bin/,$(basename $(notdir $(SRC_SERVICE_PERL))))

STARMAN_WORKERS = 5

#DATA_API_URL = https://www.patricbrc.org/api
DATA_API_URL = https://p3.theseed.org/services/data_api
APP_SERVICE_URL = https://p3.theseed.org/services/app_service

#
# For Ubuntu latest, we use system compiler
#
REL=$(shell lsb_release -i -s)$(shell lsb_release -r -s)
ifeq ($(REL),Ubuntu22.04)
BUILD_TOOLS=/usr
else
ifeq ($(wildcard $(DEPLOY_RUNTIME)/gcc-9.3.0),)
BUILD_TOOLS = $(DEPLOY_RUNTIME)/build-tools
else
BUILD_TOOLS = $(DEPLOY_RUNTIME)/gcc-9.3.0
endif
endif
CXX = $(BUILD_TOOLS)/bin/g++

# CXX_HANDLER_TRACKING = -DBOOST_ASIO_ENABLE_HANDLER_TRACKING

ifneq ($(REL),Ubuntu22.04)
BOOST = $(DEPLOY_RUNTIME)/boost-latest
endif

INCLUDES = -I$(BOOST)/include
CXXFLAGS = $(INCLUDES) -g  -std=c++14 $(CXX_HANDLER_TRACKING)
CXX_LDFLAGS = -Wl,-rpath,$(BUILD_TOOLS)/lib64 -Wl,-rpath,$(BOOST)/lib
LDFLAGS = -L$(BOOST)/lib

ifeq ($(REL),Ubuntu22.04)
	LIBS = -lboost_system -lboost_filesystem -lboost_timer -lboost_chrono \
		-lboost_iostreams -lboost_regex -lboost_thread -lboost_program_options -lboost_system \
		-lpthread
else
LIBS = $(BOOST)/lib/libboost_system.a \
	$(BOOST)/lib/libboost_filesystem.a \
	$(BOOST)/lib/libboost_timer.a \
	$(BOOST)/lib/libboost_chrono.a \
	$(BOOST)/lib/libboost_iostreams.a \
	$(BOOST)/lib/libboost_regex.a \
	$(BOOST)/lib/libboost_thread.a \
	$(BOOST)/lib/libboost_program_options.a \
	$(BOOST)/lib/libboost_system.a \
	-lpthread
endif

ifdef AUTO_DEPLOY_CONFIG
CXX_DEFINES = -DAPP_SERVICE_URL='"$(APP_SERVICE_URL)"' -DDATA_API_URL='"$(DATA_API_URL)"' -DDEPLOY_LIBDIR='"$(TARGET)/lib"'
else
CXX_DEFINES = -DAPP_SERVICE_URL='"$(APP_SERVICE_URL)"' -DDATA_API_URL='"$(DATA_API_URL)"' -DDEPLOY_LIBDIR='"$(CURDIR)"'
endif

all: binaries

deploy-client: p3x-preload.so
	cp p3x-preload.so $(DEPLOY_TARGET)/lib/p3x-preload.so
	rm -f p3x-app-shepherd  
	$(MAKE) p3x-app-shepherd
	mv p3x-app-shepherd $(DEPLOY_TARGET)/bin/p3x-app-shepherd

deply-service:

binaries: $(TOP_DIR)/bin/p3x-app-shepherd $(TOP_DIR)/bin/p3x-preload.so

tj: tj.cc
	PATH=$(BUILD_TOOLS)/bin:$$PATH $(CXX)  -g -o $@ $^ $(CXXFLAGS) $(LDFLAGS) $(CXX_LDFLAGS) $(LIBS)

p3x-preload.so: p3x-preload.c
	cc -shared  -fPIC $^ -o $@ -ldl

examp: examp.o
	PATH=$(BUILD_TOOLS)/bin:$$PATH $(CXX) -g -o $@ $^ $(CXXFLAGS) $(LDFLAGS) $(CXX_LDFLAGS) $(LIBS) -lssl -lcrypto


tcli: tcli.o app_client.o app_request.o buffer.o
	PATH=$(BUILD_TOOLS)/bin:$$PATH $(CXX) -g -o $@ $^ $(CXXFLAGS) $(LDFLAGS) $(CXX_LDFLAGS) $(LIBS) -lssl -lcrypto
tcli.o: app_client.h app_request.h buffer.h

p3x-app-shepherd: p3x-app-shepherd.o pidinfo.o app_client.o buffer.o app_request.o deploy_data.cc 
	PATH=$(BUILD_TOOLS)/bin:$$PATH $(CXX) $(CXX_DEFINES) -g -o $@ $^ $(CXXFLAGS) $(LDFLAGS) $(CXX_LDFLAGS) $(LIBS) -lssl -lcrypto

$(TOP_DIR)/bin/%: %
	cp $^ $@

%.o: %.cpp
	PATH=$(BUILD_TOOLS)/bin:$$PATH $(CXX) -c $< $(CXXFLAGS)

%.o: %.cc
	PATH=$(BUILD_TOOLS)/bin:$$PATH $(CXX) -c $< $(CXXFLAGS)

p3x-app-shepherd.o: pidinfo.h clock.h app_client.h buffer.h app_request.h

p3x-calc-start-time-offset: p3x-calc-start-time-offset.c
	$(CC) -g -Wall -o $@ $^

pidinfo.o: pidinfo.h clock.h 

buffer.o: buffer.h

app_client.o: app_client.h app_request.h buffer.h
app_client.h: url_parse.h

app_request.o: app_request.h buffer.h
app_request.h: url_parse.h

pidinfo: pidinfo.cc
	PATH=$(BUILD_TOOLS)/bin:$$PATH $(CXX) -DPIDINFO_TEST_MAIN -g -o $@ $^ $(CXXFLAGS) $(LDFLAGS) $(CXX_LDFLAGS) $(LIBS)

all: 

deploy: deploy-client deploy-service
deploy-all: deploy-client deploy-service
deploy-client: 

deploy-service: 

include $(TOP_DIR)/tools/Makefile.common.rules
