#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: Gabriel Marcano, 2023

fastboot flash boot $@
fastboot boot $@
